{lib, config, pkgs, ...}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.fmf.services.llama-cpp;
  vaultDefaults = config.fmf.services.vault-agent.settings.vault or {};
  vaultKey = config.fmf.services.vault-agent.services.llama-cpp.secrets.file.files.api-key.path;
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
          };
        });
        default = lib.fmf.llamaCppModels {inherit pkgs;};
        description = "Pinned GGUF store files. All entries are retained by the server closure, but only one is loaded.";
      };
    };
  };

  config = mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {assertion = !cfg.router.enable || cfg.router.models != {}; message = "llama.cpp router requires at least one model.";}
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
        modelsPreset = if cfg.router.enable then lib.mapAttrs (_: model: {
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
        }) cfg.router.models else null;
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
