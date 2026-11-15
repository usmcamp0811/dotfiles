{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.fmf.services.strata;
  vaultDefaults = config.fmf.services.vault-agent.settings.vault or {};
  vaultKey = config.fmf.services.vault-agent.services.strata.secrets.file.files.api-key.path;
  stateDir = "/var/lib/strata";

  model = cfg.models.${cfg.model};
  contextSize =
    if cfg.contextSize == null
    then model.contextSize
    else cfg.contextSize;
  tokenizer = cfg.package.tokenizerFor model.package;

  # Engine arguments exactly as Strata v0.2.13.1's setup.py writes them for qwen36 (--native <gguf>
  # --max-context N --prefill auto --mtp N), plus the optional VRAM/CPU knobs.
  engineArgs =
    [
      "--native"
      "${model.package}"
      "--max-context"
      (toString contextSize)
      "--prefill"
      "auto"
      "--mtp"
      (toString (if cfg.mtp == null then model.mtp else cfg.mtp))
    ]
    ++ lib.optionals (cfg.expertVramGiB != null) ["--expert-vram" (toString cfg.expertVramGiB)]
    ++ lib.optionals (cfg.vramReserveMiB != null) ["--vram-reserve-mib" (toString cfg.vramReserveMiB)]
    ++ lib.optionals (cfg.poolWorkers != null) ["--pool-workers" (toString cfg.poolWorkers)]
    ++ cfg.extraEngineArgs;

  # The run config (strata-<model>.json in upstream). The API key is deliberately NOT in it: this file is in the
  # Nix store. The key reaches the server as $STRATA_API_KEY (see the launcher).
  isMock = cfg.engine == "mock";

  runConfigAttrs = {
      args = engineArgs;
      cwd = stateDir;
      model_name = cfg.model;
      inherit (model) arch;
      log = "${stateDir}/engine.log";
      lib_dirs = ["/run/opengl-driver/lib"];
      port = cfg.port;
      host = cfg.host;
    }
    # The mock engine needs neither the engine binary nor a tokenizer (the server falls back to a byte tokenizer):
    # a VM test then does not have to build or fetch the real ones.
    // lib.optionalAttrs (!isMock) {
      exe = cfg.package.enginePath;
      tokenizer = "${tokenizer}/tokenizer";
    }
    // lib.optionalAttrs cfg.lazyLoad {lazy_load = true;}
    // lib.optionalAttrs (cfg.idleUnloadSeconds != null) {idle_unload_s = cfg.idleUnloadSeconds;}
    // lib.optionalAttrs (cfg.minFreeVramMiB != null) {min_free_vram_mib = cfg.minFreeVramMiB;}
    // lib.optionalAttrs (cfg.parallel > 1) {parallel = cfg.parallel;}
    // cfg.extraConfig;

  runConfig = pkgs.writeText "strata-${cfg.model}.json" (builtins.toJSON runConfigAttrs);

  keyPath =
    if cfg.vault.enable
    then vaultKey
    else "/run/credentials/strata.service/api-key";

  launcherText = ''
    set -eu
    key_file=${lib.escapeShellArg keyPath}
    if [ ! -r "$key_file" ]; then
      echo "strata: API key file $key_file is missing or unreadable; refusing to start without authentication" >&2
      exit 1
    fi
    key="$(${pkgs.coreutils}/bin/cat "$key_file")"
    if ! printf '%s' "$key" | ${pkgs.gnugrep}/bin/grep -Eq '^[[:graph:]]{32,256}$'; then
      echo "strata: API key must be 32-256 printable characters without spaces; refusing to start" >&2
      exit 1
    fi
    ${lib.optionalString (!isMock) ''
      if [ ! -r ${lib.escapeShellArg "${model.package}"} ]; then
        echo "strata: model file ${model.package} is missing" >&2
        exit 1
      fi
      if [ ! -x ${lib.escapeShellArg cfg.package.enginePath} ]; then
        echo "strata: engine ${cfg.package.enginePath} is missing" >&2
        exit 1
      fi
    ''}
    # The server reads its key from the environment, never from argv (visible in `ps`) or the store.
    export STRATA_API_KEY="$key"
    unset key
    exec ${cfg.package}/bin/strata-server --engine ${cfg.engine} --config ${runConfig} \
      --host ${lib.escapeShellArg cfg.host} --port ${toString cfg.port} --offline
  '';

  launcher = pkgs.writeShellScript "strata-start" launcherText;

  statusCommand = pkgs.writeShellScriptBin "strata-status" ''
    url="http://${if cfg.host == "0.0.0.0" then "127.0.0.1" else cfg.host}:${toString cfg.port}"
    echo "== /health (unauthenticated) =="
    ${pkgs.curl}/bin/curl -fsS -m 5 "$url/health"; echo
    if [ -r ${lib.escapeShellArg keyPath} ]; then
      echo "== /v1/models =="
      printf 'header = "Authorization: Bearer %s"\n' "$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg keyPath})" |
        ${pkgs.curl}/bin/curl -fsS -m 5 -K - "$url/v1/models"; echo
    else
      echo "(key ${keyPath} not readable by this user: skipping the authenticated check)"
    fi
  '';
in {
  options.fmf.services.strata = {
    enable = lib.mkEnableOption "Strata inference server (CUDA, GPU+RAM expert placement for MoE models)";

    package = mkOption {
      type = types.package;
      default = pkgs.fmf.strata;
      defaultText = lib.literalExpression "pkgs.fmf.strata";
      description = ''
        The pinned Strata build: CUDA engine, Python server and tokenizer builder. Override
        `cudaArchitectures` (default `["89"]`, Ada) for another GPU:
        `pkgs.fmf.strata.override { cudaArchitectures = ["86"]; }`.
      '';
    };

    engine = mkOption {
      type = types.enum ["strata" "mock"];
      default = "strata";
      internal = true;
      description = "`mock` runs the server's scripted mock engine (no GPU, no weights). For NixOS VM tests only.";
    };

    generated = mkOption {
      internal = true;
      readOnly = true;
      type = types.attrs;
      default = {inherit runConfigAttrs launcherText;};
      description = "The run config (as data) and the launcher script text, so tests can inspect what is generated without building anything.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen on. Strata's own default is loopback; widen it only behind the API key.";
    };
    port = mkOption {
      type = types.port;
      default = 18081;
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
    };

    models = mkOption {
      type = types.attrsOf types.attrs;
      default = lib.fmf.strataModels {inherit pkgs;};
      defaultText = lib.literalExpression "lib.fmf.strataModels { inherit pkgs; }";
      description = "Models Strata can serve (see lib/strata-models). Only the selected one is built into the closure.";
    };
    model = mkOption {
      type = types.str;
      default = "qwen3.6-35b-a3b-ud-q4_k_xl";
      description = ''
        Which catalog model this instance serves. One instance serves exactly one model and answers every
        request with it, whatever model id the client sends.
      '';
    };
    contextSize = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = ''
        Context window in tokens; null uses the catalog value. The KV cache lives in VRAM
        (45,056 bytes per token for Qwen3.6: 2.75 GiB at 64K), competing with the experts that would
        otherwise sit on the GPU. The engine refuses a window that cannot fit and says why.
      '';
    };
    mtp = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      description = "Draft tokens per step (`--mtp`); null uses the catalog value (2). 0 turns drafting off.";
    };
    parallel = mkOption {
      type = types.ints.between 1 8;
      default = 1;
      description = ''
        Requests answered at once. Every extra slot keeps its own KV cache in VRAM, so slots cost
        expert room on a 16 GB card (upstream's table: 16 GB, hybrid mode, 2 slots at 32K).
      '';
    };

    expertVramGiB = mkOption {
      type = types.nullOr (types.either types.int types.float);
      default = null;
      description = ''
        Explicit VRAM budget for GPU-resident experts (`--expert-vram`, GiB). null lets the engine decide:
        every expert in VRAM when they fit, otherwise the most-used experts on the GPU and the rest computed on
        the CPU from a pinned RAM copy (the hybrid mode).
      '';
    };
    vramReserveMiB = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      description = "VRAM left free for other programs (`--vram-reserve-mib`, engine default 700). Raise it on a GPU that also drives a desktop.";
    };
    poolWorkers = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = ''
        CPU threads computing experts (`--pool-workers`). null keeps the engine's default: one worker per
        physical core except the main thread's, one fewer again on CPUs with 17+ cores (15 on a 16-core
        9950X3D), single socket. Not benchmarked here: measure before setting.
      '';
    };
    extraEngineArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra engine flags appended to the run config's args.";
    };
    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Extra keys merged into the run config (e.g. `sampling`, `aliases`). Never put the API key here: it is stored in the Nix store.";
    };

    lazyLoad = mkOption {
      type = types.bool;
      default = false;
      description = "Start the API with the model unloaded; the first request loads it (text only).";
    };
    idleUnloadSeconds = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Unload the model after this long without requests, returning VRAM to other programs (llama.cpp, the desktop). The next request reloads it.";
    };
    minFreeVramMiB = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Load an unloaded model only when this much VRAM is free; otherwise answer 503.";
    };

    memoryMax = mkOption {
      type = types.nullOr types.str;
      default = "80%";
      description = ''
        systemd MemoryMax for the service (bytes with a suffix, or a percentage of RAM). The hybrid mode keeps a
        pinned RAM copy of the experts (upstream measured 18.75 GiB for UD-Q4_K_XL; its planning figure is 32 GB
        of RAM for the model), plus the engine's buffers and the server. null disables the cap.
      '';
    };
    memoryHigh = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "systemd MemoryHigh: reclaim pressure above this, before MemoryMax kills.";
    };
    oomScoreAdjust = mkOption {
      type = types.ints.between (-1000) 1000;
      default = 200;
      description = "OOM killer bias. Positive makes this server a preferred victim ahead of the desktop.";
    };
    cpuAffinity = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        systemd CPUAffinity list (for example "0-7,16-23"). null leaves scheduling alone. The Qwen3.6 engine
        keeps its own worker placement and ignores `--pool-cores`, so there is no engine-side CCD pinning to
        configure; this is a blunt process-wide constraint and only worth setting after a benchmark.
      '';
    };

    apiKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Protected runtime API-key file, never a Nix-store path. Vault can provision it instead.";
    };
    vault = {
      enable = lib.mkEnableOption "Vault-provisioned Strata API key";
      path = mkOption {
        type = types.str;
        default = "";
        description = "Vault API path, including /data/ for KV v2.";
      };
      field = mkOption {
        type = types.str;
        default = "api_key";
      };
      kvVersion = mkOption {
        type = types.enum [1 2];
        default = 2;
      };
    };
  };

  config = mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.apiKeyFile != null || cfg.vault.enable;
          message = "fmf.services.strata always requires an API key: set apiKeyFile or vault.enable (no unauthenticated endpoint).";
        }
        {
          assertion = !(cfg.apiKeyFile != null && cfg.vault.enable);
          message = "Select either strata vault.enable or apiKeyFile, not both.";
        }
        {
          assertion = cfg.apiKeyFile == null || (lib.hasPrefix "/" cfg.apiKeyFile && !lib.hasPrefix "/nix/store/" cfg.apiKeyFile);
          message = "Strata API keys must be runtime absolute paths outside /nix/store.";
        }
        {
          assertion = !cfg.vault.enable || cfg.vault.path != "";
          message = "Set the Strata Vault API path.";
        }
        {
          assertion = !cfg.vault.enable || config.fmf.services.vault-agent.enable;
          message = "Strata Vault authentication requires fmf.services.vault-agent.enable.";
        }
        {
          assertion = !cfg.vault.enable || lib.all (value: value != "") [(vaultDefaults.address or "") (vaultDefaults.role-id or "") (vaultDefaults.secret-id or "")];
          message = "Strata Vault Agent requires a Vault address and AppRole role-id/secret-id file paths in fmf.services.vault-agent.settings.vault.";
        }
        {
          assertion = !cfg.vault.enable || cfg.vault.kvVersion != 2 || lib.hasInfix "/data/" cfg.vault.path;
          message = "strata vault.path must be the KV v2 API path (including /data/).";
        }
        {
          assertion = builtins.hasAttr cfg.model cfg.models;
          message = "fmf.services.strata.model '${cfg.model}' is not in the Strata catalog (${lib.concatStringsSep ", " (builtins.attrNames cfg.models)}).";
        }
        {
          # CUDA 13 engines need driver 580+ (docs/INSTALL.md). Skipped for the mock engine.
          assertion = cfg.engine == "mock" || !(config.hardware ? nvidia) || lib.versionAtLeast config.hardware.nvidia.package.version "580";
          message = "The Strata CUDA 13 engine needs NVIDIA driver 580 or newer (hardware.nvidia.package is ${config.hardware.nvidia.package.version}).";
        }
      ];

      users.groups.strata = {};
      users.users.strata = {
        isSystemUser = true;
        group = "strata";
        home = stateDir;
        extraGroups = ["video" "render"];
        description = "Strata inference server";
      };

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
      environment.systemPackages = [statusCommand];

      systemd.services.strata = {
        description = "Strata inference server (${cfg.model})";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        environment = {
          HOME = stateDir;
          TMPDIR = "${stateDir}/tmp";
          XDG_CACHE_HOME = "${stateDir}/cache";
          XDG_CONFIG_HOME = "${stateDir}/config";
          XDG_STATE_HOME = "${stateDir}/state";
          PYTHONNOUSERSITE = "1";
        };
        serviceConfig =
          {
            ExecStart = launcher;
            User = "strata";
            Group = "strata";
            SupplementaryGroups = ["video" "render"];
            StateDirectory = ["strata" "strata/tmp" "strata/cache" "strata/config" "strata/state"];
            StateDirectoryMode = "0750";
            WorkingDirectory = stateDir;
            UMask = "0077";

            # A refused context or a missing GPU should not spin the GPU: back off, then stop retrying.
            Restart = "on-failure";
            RestartSec = 30;
            TimeoutStopSec = 60;
            OOMScoreAdjust = cfg.oomScoreAdjust;
            # The hybrid mode pins a RAM copy of the experts for the GPU to read.
            LimitMEMLOCK = "infinity";
            LimitNOFILE = 1048576;

            # CUDA needs executable mappings and /proc, and the NVIDIA device nodes (as the llama.cpp module).
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictNamespaces = true;
            LockPersonality = true;
            RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
            SystemCallArchitectures = "native";
          }
          // lib.optionalAttrs (cfg.apiKeyFile != null) {LoadCredential = ["api-key:${cfg.apiKeyFile}"];}
          // lib.optionalAttrs (cfg.memoryMax != null) {MemoryMax = cfg.memoryMax;}
          // lib.optionalAttrs (cfg.memoryHigh != null) {MemoryHigh = cfg.memoryHigh;}
          // lib.optionalAttrs (cfg.cpuAffinity != null) {CPUAffinity = cfg.cpuAffinity;};
        unitConfig = {
          StartLimitIntervalSec = 900;
          StartLimitBurst = 5;
        };
      };
    }
    (mkIf cfg.vault.enable {
      # Same pattern as llama-cpp: the sidecar renders the key owned by the service user and restarts the unit
      # when the secret changes. A template alone leaves auto_auth.method empty, so the agent is configured here.
      fmf.services.vault-agent.services.strata.settings = {
        vault.address = vaultDefaults.address or "";
        auto_auth.method = [
          {
            type = "approle";
            config = {
              role_id_file_path = vaultDefaults.role-id or "";
              secret_id_file_path = vaultDefaults.secret-id or "";
              remove_secret_id_file_after_reading = false;
            };
          }
        ];
      };
      fmf.services.vault-agent.services.strata.secrets.file.files.api-key = {
        text = ''
          {{- with secret ${builtins.toJSON cfg.vault.path} -}}
          {{- index ${
            if cfg.vault.kvVersion == 2
            then ".Data.data"
            else ".Data"
          } ${builtins.toJSON cfg.vault.field} -}}
          {{- end -}}
        '';
        permissions = "0400";
        change-action = "restart";
      };
    })
  ]);
}
