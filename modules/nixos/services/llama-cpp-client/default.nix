{config, lib, pkgs, ...}: let
  cfg = config.fmf.services.llama-cpp-client;
in {
  options.fmf.services.llama-cpp-client = {
    enable = lib.mkEnableOption "remote llama.cpp OpenCode client and runtime credential";
    user = lib.mkOption {
      type = lib.types.strMatching "[a-z_][a-zA-Z0-9_-]*";
      default = config.fmf.user.name;
    };
    baseURL = lib.mkOption {type = lib.types.str; default = "http://127.0.0.1:18080/v1";};
    apiKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vault/users/${cfg.user}/llama_api_key";
      description = "Runtime user-readable key file. With Vault enabled, use the default path.";
    };
    vault = {
      enable = lib.mkOption {type = lib.types.bool; default = true;};
      path = lib.mkOption {type = lib.types.str; default = ""; description = "Vault API path; include /data/ for KV v2.";};
      field = lib.mkOption {type = lib.types.str; default = "api_key";};
      kvVersion = lib.mkOption {type = lib.types.enum [1 2]; default = 2;};
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {assertion = builtins.hasAttr cfg.user config.users.users; message = "llama.cpp client user must already exist.";}
        {assertion = !cfg.vault.enable || (cfg.vault.path != "" && cfg.apiKeyFile == "/var/lib/vault/users/${cfg.user}/llama_api_key"); message = "llama.cpp Vault client requires vault.path and the default user-secrets apiKeyFile.";}
        {assertion = !cfg.vault.enable || config.fmf.services.vault-agent.enable; message = "llama.cpp Vault client requires fmf.services.vault-agent.enable.";}
      ];
      home-manager.users.${cfg.user}.fmf.tools.agentic-ai.llamaCpp = {
        enable = true;
        inherit (cfg) baseURL apiKeyFile;
      };
    }
    (lib.mkIf cfg.vault.enable {
      # Reuse the existing user-secret renderer and copy service. Only this
      # file's template comes from the dedicated shared inference secret.
      fmf.services.user-secrets = {
        enable = true;
        users.${cfg.user}.files = ["llama_api_key"];
      };
      fmf.services.vault-agent.services."user-secrets-${cfg.user}".secrets.file.files."${cfg.user}-llama_api_key".text = lib.mkForce ''
        {{- with secret ${builtins.toJSON cfg.vault.path} -}}
        {{- index ${if cfg.vault.kvVersion == 2 then ".Data.data" else ".Data"} ${builtins.toJSON cfg.vault.field} -}}
        {{- end -}}
      '';
    })
  ]);
}
