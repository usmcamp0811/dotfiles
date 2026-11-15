{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.fmf.services.strata-client;
in {
  options.fmf.services.strata-client = {
    enable = lib.mkEnableOption "remote Strata OpenCode client and runtime credential";
    user = lib.mkOption {
      type = lib.types.strMatching "[a-z_][a-zA-Z0-9_-]*";
      default = config.fmf.user.name;
    };
    baseURL = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:18081/v1";
      description = "OpenAI-compatible Strata API base URL. Use HTTPS across the network.";
    };
    apiKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vault/users/${cfg.user}/strata_api_key";
      description = "Runtime user-readable key file. With Vault enabled, use the default path.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3.6-35b-a3b-ud-q4_k_xl";
      description = "The one model the server serves; `opencode --model strata/<this>`. Must match the server's `fmf.services.strata.model`.";
    };
    contextSize = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Context window to advertise for `model`; null uses the catalog value. Must match the server's `fmf.services.strata.contextSize`.";
    };
    models = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.contextSize = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.positive;
          default = null;
          description = "Context window to advertise for this model; null uses the catalog value. Must match the server's setting for it.";
        };
      });
      default = {${cfg.model} = {contextSize = cfg.contextSize;};};
      defaultText = lib.literalExpression "{ \${model} = { contextSize = contextSize; }; }";
      description = ''
        The models to offer in OpenCode, by catalog id, against a server that switches between them
        (`fmf.services.strata.router.models`: list the same ids). Ignores `model` and `contextSize` once set.
      '';
    };
    vault = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Vault API path; include /data/ for KV v2.";
      };
      field = lib.mkOption {
        type = lib.types.str;
        default = "api_key";
      };
      kvVersion = lib.mkOption {
        type = lib.types.enum [1 2];
        default = 2;
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = builtins.hasAttr cfg.user config.users.users;
          message = "Strata client user must already exist.";
        }
        {
          assertion = !cfg.vault.enable || (cfg.vault.path != "" && cfg.apiKeyFile == "/var/lib/vault/users/${cfg.user}/strata_api_key");
          message = "Strata Vault client requires vault.path and the default user-secrets apiKeyFile.";
        }
        {
          assertion = !cfg.vault.enable || config.fmf.services.vault-agent.enable;
          message = "Strata Vault client requires fmf.services.vault-agent.enable.";
        }
        {
          assertion = !cfg.vault.enable || cfg.vault.kvVersion != 2 || lib.hasInfix "/data/" cfg.vault.path;
          message = "Strata client vault.path must include /data/ for KV v2.";
        }
      ];
      # Only the provider and a credential: no engine, no model weights, no CUDA on a client.
      home-manager.users.${cfg.user}.fmf.tools.agentic-ai.strata = {
        enable = true;
        inherit (cfg) baseURL apiKeyFile model contextSize models;
      };
    }
    (lib.mkIf cfg.vault.enable {
      # Reuse the existing user-secret renderer and copy service, as llama-cpp-client does. Only this file's
      # template comes from the dedicated shared inference secret.
      fmf.services.user-secrets = {
        enable = true;
        users.${cfg.user}.files = ["strata_api_key"];
      };
      fmf.services.vault-agent.services."user-secrets-${cfg.user}".secrets.file.files."${cfg.user}-strata_api_key".text = lib.mkForce ''
        {{- with secret ${builtins.toJSON cfg.vault.path} -}}
        {{- index ${
          if cfg.vault.kvVersion == 2
          then ".Data.data"
          else ".Data"
        } ${builtins.toJSON cfg.vault.field} -}}
        {{- end -}}
      '';
    })
  ]);
}
