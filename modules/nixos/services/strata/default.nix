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

  # Three engine paths, selected by the catalog entry (lib/strata-models). Each one's arguments and run-config keys
  # are what Strata v0.2.13.1 writes for it: strata_control/setup_config.py (config_for, dsv41_config_for) and
  # setup.py (install_own_path for qwen36).
  isQwen36 = model.family == "qwen36";
  isFlash = model.family == "flashnext";
  isDeepseek = model.family == "deepseek41";

  # A sharded model is read through a directory of symlinks under the sibling file names (packages/applications/strata).
  farm = cfg.package.farmFor cfg.model model;
  # What setup.py's "preparing the model for Strata" step builds, as a pure derivation: Flash-Next's pack
  # (tools/iq_pack.py), DeepSeek's pack (tools/dsv41/pack_gguf.py). Qwen3.6 only needs a tokenizer, from the GGUF.
  pack =
    if isFlash
    then cfg.package.packFlashNext cfg.model model
    else if isDeepseek
    then cfg.package.packDeepseek cfg.model model
    else null;
  tokenizerDir =
    if isQwen36
    then "${cfg.package.tokenizerFor model.package}/tokenizer"
    else "${pack}/tokenizer";

  # `mtp` means a count of draft tokens for qwen36 (`--mtp N`). Flash-Next takes a folder with the draft layer's
  # weights instead, so there it is only on or off: 0 is off (setup.py's `--mtp off`: `"mtp": false` in the run
  # config, which removes --mtp and --spec-min-p and keeps --spec). DeepSeek has no MTP draft layer.
  mtpSetting =
    if cfg.mtp == null
    then (model.mtp or 1)
    else cfg.mtp;
  draftOn = mtpSetting > 0;

  # The knobs that exist in every path's engine.
  poolWorkersArgs = lib.optionals (cfg.poolWorkers != null) ["--pool-workers" (toString cfg.poolWorkers)];

  # qwen36: `--native <gguf> --max-context N --prefill auto --mtp N`, plus the optional VRAM/CPU knobs. Note that the
  # Qwen3.6 engine (strata-q36) answers `--vram-reserve-mib` in serve mode with "ignoring ... (not an option of this
  # engine)": its own knob is --expert-vram. The flag is still passed, as before, so nothing changes for it.
  qwen36Args =
    [
      "--native"
      "${model.package}"
      "--max-context"
      (toString contextSize)
      "--prefill"
      "auto"
      "--mtp"
      (toString mtpSetting)
    ]
    ++ lib.optionals (cfg.expertVramGiB != null) ["--expert-vram" (toString cfg.expertVramGiB)]
    ++ lib.optionals (cfg.vramReserveMiB != null) ["--vram-reserve-mib" (toString cfg.vramReserveMiB)]
    ++ poolWorkersArgs;

  # Flash-Next, in the order setup_config.config_for writes them for a text-only start on one NVIDIA card: the pack
  # and the first shard (the engine finds the other shards beside it by name), the expert profile from the Strata
  # tree (read only unless --expert-profile-save is given), the draft layer's folder, the context, and `--kv int8`
  # above 8192 tokens. KV streaming (--kv-resident) starts at 64K and is not written: pass it in extraEngineArgs.
  flashArgs =
    [
      "--pack"
      "${pack}"
      "--native"
      "${farm}/${model.native}"
    ]
    ++ lib.optionals (model.ple != null) ["--ple-gguf" "${farm}/${model.ple}"]
    ++ [
      "--expert-profile"
      "${cfg.package.root}/data/${model.profile}"
      "--expert-cache"
      "auto"
      "--prefill"
      "auto"
      "--spec"
      "4"
    ]
    ++ lib.optionals draftOn [
      "--spec-min-p"
      "0.5"
      "--mtp"
      "${cfg.package.mtpRt}"
    ]
    ++ ["--max-context" (toString contextSize)]
    ++ lib.optionals (contextSize > 8192) ["--kv" "int8"]
    ++ lib.optionals (cfg.residentBudgetGiB != null) ["--resident-budget-gib" (toString cfg.residentBudgetGiB)]
    ++ lib.optionals (cfg.vramReserveMiB != null) ["--vram-reserve-mib" (toString cfg.vramReserveMiB)]
    ++ poolWorkersArgs;

  # DeepSeek (dsv41_config_for): the pack and the context, `--eos 1`, no pictures (the pack is made without the
  # picture reader), the DSpark drafter chosen by the engine (`--dspark auto`, never `off`: that still loads it) with
  # upstream's confidence floor for the ISTA-DAS sets, and --profile-readonly because the pack is in the store.
  # `--reserve-mib` is this engine's name for the VRAM left free.
  deepseekArgs =
    [
      "--pack"
      "${pack}"
      "--max-context"
      (toString contextSize)
      "--eos"
      "1"
      "--vision"
      "off"
      "--dspark"
      "auto"
      "--dspark-conf"
      "0.65"
      "--profile-readonly"
    ]
    ++ lib.optionals (cfg.vramReserveMiB != null) ["--reserve-mib" (toString cfg.vramReserveMiB)];

  engineArgs =
    (
      if isQwen36
      then qwen36Args
      else if isFlash
      then flashArgs
      else deepseekArgs
    )
    ++ cfg.extraEngineArgs;

  # Unsloth files: upstream's unsloth_default_env. The K-quant MMQ prompt kernels for UD-Q5_K_XL and UD-Q6_K_XL, and
  # STRATA_ROUTE_TAIL_SKIP=0 where every expert is in RAM (the skip costs accuracy there); the RAM-budget mode keeps it.
  runEnv = lib.optionalAttrs (isFlash && model.recipe == "unsloth") (
    lib.optionalAttrs model.mmqKq {STRATA_MMQ_KQ = "1";}
    // lib.optionalAttrs (cfg.residentBudgetGiB == null) {STRATA_ROUTE_TAIL_SKIP = "0";}
  );

  engineExe =
    if isDeepseek
    then cfg.package.enginePathDsv41
    else cfg.package.enginePath;

  # The run config (strata-<model>.json in upstream). The API key is deliberately NOT in it: this file is in the
  # Nix store. The key reaches the server as $STRATA_API_KEY (see the launcher).
  isMock = cfg.engine == "mock";

  runConfigAttrs = {
      args = engineArgs;
      cwd = stateDir;
      model_name = cfg.model;
      log = "${stateDir}/engine.log";
      lib_dirs = ["/run/opengl-driver/lib"];
      port = cfg.port;
      host = cfg.host;
    }
    # qwen36 and DeepSeek write the GGUF architecture; Flash-Next writes none (the server defaults to qwen4exp).
    // lib.optionalAttrs (model ? arch) {inherit (model) arch;}
    // lib.optionalAttrs (isFlash && !draftOn) {mtp = false;}
    // lib.optionalAttrs (runEnv != {}) {env = runEnv;}
    # 300+ GB are read from the files at the first start: DeepSeek's start can take a long time (upstream: 3600).
    // lib.optionalAttrs isDeepseek {engine_ready_s = 3600;}
    # The mock engine needs neither the engine binary nor a tokenizer (the server falls back to a byte tokenizer):
    # a VM test then does not have to build or fetch the real ones.
    // lib.optionalAttrs (!isMock) {
      exe = engineExe;
      tokenizer = tokenizerDir;
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
      if [ ! -x ${lib.escapeShellArg engineExe} ]; then
        echo "strata: engine ${engineExe} is missing" >&2
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
      description = ''
        Qwen3.6: draft tokens per step (`--mtp`); null uses the catalog value (2). 0 turns drafting off.
        Qwen3.8 Flash Next: the draft layer is a folder of weights, so this is on or off only; 0 turns it off
        (about 1 GB of VRAM and 5 GB of store saved, slower decoding), anything else leaves it on.
        DeepSeek: no draft layer; ignored.
      '';
    };
    residentBudgetGiB = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = ''
        Qwen3.8 Flash Next from Unsloth only (`--resident-budget-gib`): GiB of experts kept in RAM, the most used
        first; the rest are read from the GGUF on the SSD. null keeps every expert in RAM, which is what setup.py
        writes where the experts and 16 GB beside them fit the machine. Upstream's rule for the budget when they do
        not is the RAM in GiB less 24, which is the case for Q8_0 on 128 GB (its experts are 128.3 GB). Setting it
        also stops the module writing `STRATA_ROUTE_TAIL_SKIP=0`, as setup.py does for the budget mode.
      '';
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
        # Options that name a flag only one engine has are refused for the others instead of being dropped silently.
        # (They are skipped for an unknown model, so the catalog message above is the one that is shown.)
        {
          assertion = !(builtins.hasAttr cfg.model cfg.models) || cfg.expertVramGiB == null || isQwen36;
          message = "fmf.services.strata.expertVramGiB (--expert-vram) is an option of the Qwen3.6 engine only; model '${cfg.model}' is served by another engine.";
        }
        {
          assertion = !(builtins.hasAttr cfg.model cfg.models) || cfg.residentBudgetGiB == null || (isFlash && model.recipe == "unsloth");
          message = "fmf.services.strata.residentBudgetGiB applies to the Unsloth Qwen3.8 Flash Next models only; model '${cfg.model}' is not one.";
        }
        {
          assertion = !(builtins.hasAttr cfg.model cfg.models) || cfg.poolWorkers == null || !isDeepseek;
          message = "fmf.services.strata.poolWorkers (--pool-workers) is not an option of the DeepSeek engine; model '${cfg.model}' uses it.";
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
