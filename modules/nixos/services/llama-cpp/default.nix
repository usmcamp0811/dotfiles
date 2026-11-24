{lib, config, pkgs, ...}: let
  inherit (lib) mkOption mkIf types;
  # fmf modules are not always handed `utils` (Snowfall wraps them); take it from nixpkgs as the NixOS service does.
  utils = import "${pkgs.path}/nixos/lib/utils.nix" {inherit lib config pkgs;};
  cfg = config.fmf.services.llama-cpp;
  vaultDefaults = config.fmf.services.vault-agent.settings.vault or {};
  vaultKey = config.fmf.services.vault-agent.services.llama-cpp.secrets.file.files.api-key.path;

  # One router worker is the router binary itself, so a router can only load models its own runtime can read.
  # Models that need another llama.cpp build therefore go to a router of that build (`runtimes`); the models
  # with `runtime = null` stay on the original service.
  modelsOf = runtime: lib.filterAttrs (_: model: model.runtime == runtime) cfg.router.models;
  presetOf = models: lib.mapAttrs (_: model: {
    model = toString model.package;
    ctx-size = model.contextSize;
    n-gpu-layers = model.gpuLayers;
    parallel = 1;
    batch-size = 256;
    ubatch-size = 128;
    flash-attn = "auto";
    fit = "on";
    fit-target = 2048;
    # Bound SWA/recurrent checkpoint overhead on small GPUs. Reusing
    # older prefixes may require more recomputation, not less context.
    ctx-checkpoints = 1;
    jinja = true;
    load-on-startup = false;
    sleep-idle-seconds = 300;
  } // lib.optionalAttrs (model.mmproj != null) {mmproj = toString model.mmproj;} // model.extraPreset) models;
  mainService = config.systemd.services.llama-cpp;
in {
  options.fmf.services.llama-cpp = {
    enable = lib.mkEnableOption "llama.cpp inference server";
    package = mkOption {
      type = types.package;
      default = pkgs.llama-cpp.override {cudaSupport = cfg.cudaSupport;};
      description = "llama.cpp package; router mode requires model-preset/router support.";
    };
    cudaSupport = mkOption {type = types.bool; default = false;};
    port = mkOption {type = types.port; default = 18080;};
    host = mkOption {type = types.str; default = "0.0.0.0";};
    openFirewall = mkOption {type = types.bool; default = false;};
    model = mkOption {
      type = types.nullOr types.str;
      default = "${pkgs.fmf.mistral-7b-instruct}";
      description = "Single-model GGUF path; ignored in router mode.";
    };
    extraFlags = mkOption {type = types.listOf types.str; default = [];};
    apiKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Protected runtime API-key file, never a Nix-store path. Vault can provision it instead.";
    };
    vault = {
      enable = lib.mkEnableOption "Vault-provisioned llama.cpp API key";
      path = mkOption {type = types.str; default = ""; description = "Vault API path, including /data/ for KV v2.";};
      field = mkOption {type = types.str; default = "api_key";};
      kvVersion = mkOption {type = types.enum [1 2]; default = 2;};
    };
    router = {
      enable = lib.mkEnableOption "on-demand model switching (one loaded model maximum)";
      models = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            package = mkOption {type = types.package;};
            name = mkOption {type = types.str; default = "";};
            contextSize = mkOption {type = types.ints.positive; default = 8192;};
            maxOutputTokens = mkOption {type = types.ints.positive; default = 2048;};
            gpuLayers = mkOption {type = types.str; default = "auto";};
            runtime = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Name in `runtimes` of the llama.cpp build that serves this model; null is this service's own `package`.";
            };
            mmproj = mkOption {
              type = types.nullOr types.package;
              default = null;
              description = "Multimodal projector GGUF; enables image input for this model.";
            };
            vision = mkOption {
              type = types.bool;
              default = false;
              description = "Whether clients may send images (only the client catalog reads this; set `mmproj` for the server).";
            };
            extraPreset = mkOption {
              type = types.attrsOf (types.oneOf [types.str types.int types.bool]);
              default = {};
              description = "Preset keys merged over the defaults (sampling, flash-attn, fit, ...), for this model only.";
            };
          };
        });
        default = lib.filterAttrs (_: model: (model.runtime or null) == null || cfg.runtimes ? ${model.runtime}) (lib.fmf.llamaCppModels {inherit pkgs;});
        defaultText = lib.literalExpression "lib.fmf.llamaCppModels { inherit pkgs; }, without the models whose runtime is not in `runtimes`";
        description = "Pinned GGUF store files. All entries are retained by the server closure, but only one per router is loaded.";
      };
    };
    runtimes = mkOption {
      default = {};
      description = ''
        Other llama.cpp builds, each its own router (`llama-cpp-<name>.service`) with the same authentication, hardening
        and `--models-max 1`, for models the main `package` cannot run. The main service and its models are unchanged.
        A router loads one model at a time, so with N runtimes up to N+1 models can be resident at once; every router
        unloads after its idle timeout, and a model that cannot fit fails to load instead of evicting another.
        Serve them behind one front door by path (`/<name>/v1`).
      '';
      type = types.attrsOf (types.submodule {
        options = {
          package = mkOption {type = types.package; description = "llama.cpp build for this runtime.";};
          port = mkOption {type = types.port; description = "Listen port; must differ from the main service and the other runtimes.";};
        };
      });
    };
  };

  config = mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {assertion = !cfg.router.enable || modelsOf null != {}; message = "llama.cpp router requires at least one model on the main runtime.";}
        {assertion = cfg.runtimes == {} || cfg.router.enable; message = "llama.cpp runtimes serve router models; enable router mode.";}
        {
          assertion = !cfg.router.enable || lib.all (model: model.runtime == null || cfg.runtimes ? ${model.runtime}) (lib.attrValues cfg.router.models);
          message = "A llama.cpp router model names a runtime that is not defined in fmf.services.llama-cpp.runtimes.";
        }
        {
          assertion = let ports = [cfg.port] ++ lib.mapAttrsToList (_: rt: rt.port) cfg.runtimes; in lib.length (lib.unique ports) == lib.length ports;
          message = "The llama.cpp main service and its runtimes need distinct ports.";
        }
        {
          # A GGUF that needs a specific build (e.g. PTQ1_0 needs the PrismML fork) says so; it must not be served by another.
          assertion = !cfg.router.enable || lib.all (model: (model.package.passthru.runtime or (if model.runtime == null then "default" else model.runtime)) == (if model.runtime == null then "default" else model.runtime)) (lib.attrValues cfg.router.models);
          message = "A llama.cpp model is assigned to a runtime other than the one its package declares (passthru.runtime).";
        }
        {assertion = !cfg.vault.enable || cfg.vault.path != ""; message = "Set the llama.cpp Vault API path.";}
        {assertion = !cfg.vault.enable || config.fmf.services.vault-agent.enable; message = "llama.cpp Vault authentication requires fmf.services.vault-agent.enable.";}
        {assertion = !cfg.vault.enable || lib.all (value: value != "") [(vaultDefaults.address or "") (vaultDefaults.role-id or "") (vaultDefaults.secret-id or "")]; message = "llama.cpp Vault Agent requires a Vault address and AppRole role-id/secret-id file paths in fmf.services.vault-agent.settings.vault.";}
        {assertion = !cfg.vault.enable || cfg.vault.kvVersion != 2 || lib.hasInfix "/data/" cfg.vault.path; message = "llama.cpp vault.path must be the KV v2 API path (including /data/), not the CLI/logical secret path.";}
        {assertion = cfg.apiKeyFile == null || (!lib.hasPrefix "/nix/store/" cfg.apiKeyFile && lib.hasPrefix "/" cfg.apiKeyFile); message = "llama.cpp API keys must be runtime absolute paths outside /nix/store.";}
        {assertion = !cfg.vault.enable || cfg.apiKeyFile == null; message = "Select either llama.cpp vault.enable or apiKeyFile, not both.";}
      ];
      services.llama-cpp = {
        enable = true;
        inherit (cfg) package host port openFirewall;
        model = if cfg.router.enable then null else cfg.model;
        modelsPreset = if cfg.router.enable then presetOf (modelsOf null) else null;
        extraFlags = cfg.extraFlags
          ++ lib.optionals cfg.router.enable ["--models-max" "1" "--parallel" "1" "--offline"]
          ++ lib.optionals cfg.vault.enable ["--api-key-file" vaultKey]
          ++ lib.optionals (cfg.apiKeyFile != null) ["--api-key-file" "/run/credentials/llama-cpp.service/api-key"];
      };
      systemd.services.llama-cpp.serviceConfig = lib.mkMerge [
        (mkIf (cfg.apiKeyFile != null) {LoadCredential = ["api-key:${cfg.apiKeyFile}"];})
        (mkIf cfg.cudaSupport {
          # CUDA JIT and driver discovery need executable mappings and /proc.
          MemoryDenyWriteExecute = lib.mkForce false;
          ProcSubset = lib.mkForce "all";
          PrivateUsers = lib.mkForce false;
          SupplementaryGroups = ["video" "render"];
        })
      ];
      systemd.services.llama-cpp.preStart = lib.optionalString cfg.vault.enable ''
        if ! ${pkgs.gnugrep}/bin/grep -Eq '^[[:graph:]]{32,256}$' ${lib.escapeShellArg vaultKey}; then
          echo "Missing or invalid llama.cpp API key" >&2
          exit 1
        fi
      '';
      systemd.services.llama-cpp = {
        after = ["network-online.target"];
        wants = ["network-online.target"];
      };
    }
    (mkIf (cfg.router.enable && cfg.runtimes != {}) {
      # One router per extra runtime. Everything about the unit (hardening, GPU access, user, the Vault sidecar
      # namespace, and whatever the host adds such as IP allow-lists) comes from the main unit, so a runtime can
      # never be less restricted than the service it sits next to; only the binary, port, preset and state
      # directories differ. The key is read the same way: the Vault file is shared, a credential file is
      # re-delivered under this unit's own name.
      systemd.services = lib.mapAttrs' (name: rt: lib.nameValuePair "llama-cpp-${name}" {
        description = "llama.cpp server (${name} runtime)";
        # Started with the main unit (and at boot); stopped and restarted with it (partOf). A runtime can still be
        # started, stopped or restarted alone.
        wantedBy = mainService.wantedBy ++ ["llama-cpp.service"];
        inherit (mainService) after wants requires bindsTo preStart;
        unitConfig = removeAttrs mainService.unitConfig ["Description"];
        # A rotated Vault key restarts the main unit; the others must follow.
        partOf = ["llama-cpp.service"];
        serviceConfig = mainService.serviceConfig // {
          StateDirectory = "llama-cpp-${name}";
          CacheDirectory = "llama-cpp-${name}";
          WorkingDirectory = "/var/lib/llama-cpp-${name}";
          Environment = ["LLAMA_CACHE=/var/cache/llama-cpp-${name}"];
          ExecStart = "${rt.package}/bin/llama-server " + utils.escapeSystemdExecArgs (
            ["--host" cfg.host "--port" (toString rt.port)
             "--models-preset" (pkgs.writeText "llama-models-${name}.ini" (lib.generators.toINI {} (presetOf (modelsOf name))))]
            ++ cfg.extraFlags
            ++ ["--models-max" "1" "--parallel" "1" "--offline"]
            ++ lib.optionals cfg.vault.enable ["--api-key-file" vaultKey]
            ++ lib.optionals (cfg.apiKeyFile != null) ["--api-key-file" "/run/credentials/llama-cpp-${name}.service/api-key"]
          );
        };
      }) cfg.runtimes;
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (lib.mapAttrsToList (_: rt: rt.port) cfg.runtimes);
    })
    (mkIf cfg.vault.enable {
      # Match the existing service-side Vault pattern: the sidecar renders and
      # owns the file for the service user, shares /tmp, and restarts on changes.
      users.groups.llama-cpp = {};
      users.users.llama-cpp = {isSystemUser = true; group = "llama-cpp";};
      systemd.services.llama-cpp.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "llama-cpp";
        Group = "llama-cpp";
      };
      # As in user-secrets/nix-grpc-store, configure the service's agent
      # explicitly. Registering a template alone leaves auto_auth.method empty.
      fmf.services.vault-agent.services.llama-cpp.settings = {
        vault.address = vaultDefaults.address or "";
        auto_auth.method = [{
          type = "approle";
          config = {
            role_id_file_path = vaultDefaults.role-id or "";
            secret_id_file_path = vaultDefaults.secret-id or "";
            remove_secret_id_file_after_reading = false;
          };
        }];
      };
      fmf.services.vault-agent.services.llama-cpp.secrets.file.files.api-key = {
        text = ''
          {{- with secret ${builtins.toJSON cfg.vault.path} -}}
          {{- index ${if cfg.vault.kvVersion == 2 then ".Data.data" else ".Data"} ${builtins.toJSON cfg.vault.field} -}}
          {{- end -}}
        '';
        permissions = "0400";
        change-action = "restart";
      };
    })
  ]);
}
