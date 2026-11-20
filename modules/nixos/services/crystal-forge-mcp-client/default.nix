{
  config,
  lib,
  ...
}: let
  cfg = config.fmf.services.crystal-forge-mcp-client;
  defaultTokenFile = "/var/lib/vault/users/${cfg.user}/crystal_forge_mcp_pat";
in {
  options.fmf.services.crystal-forge-mcp-client = {
    enable = lib.mkEnableOption "Crystal Forge MCP server in OpenCode, with its access token as a runtime credential";
    user = lib.mkOption {
      type = lib.types.strMatching "[a-z_][a-zA-Z0-9_-]*";
      default = config.fmf.user.name;
      description = "User whose OpenCode gets the MCP server and who can read the token.";
    };
    name = lib.mkOption {
      type = lib.types.str;
      default = "crystal-forge";
      description = "Name of the MCP server in OpenCode.";
    };
    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://crystal-forge.example.com/mcp";
      description = "The server's MCP endpoint (its services.crystal-forge.server.mcp.publicUrl). Required.";
    };
    envVar = lib.mkOption {
      type = lib.types.strMatching "[A-Z_][A-Z0-9_]*";
      default = "CF_MCP_TOKEN";
      description = "Environment variable OpenCode reads the token from (opencode.json holds only {env:<this>}).";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = defaultTokenFile;
      description = "Runtime user-readable token file. With Vault enabled, use the default path.";
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
        default = "mcp_pat";
        description = "Field at `path` holding the access token (cfat_v1_...).";
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
          message = "Crystal Forge MCP client user must already exist.";
        }
        {
          assertion = cfg.url != null && (lib.hasPrefix "https://" cfg.url || lib.hasPrefix "http://localhost" cfg.url || lib.hasPrefix "http://127.0.0.1" cfg.url);
          message = "fmf.services.crystal-forge-mcp-client.url must be set, and https:// (the token is sent with every request).";
        }
        {
          assertion = !cfg.vault.enable || (cfg.vault.path != "" && cfg.tokenFile == defaultTokenFile);
          message = "Crystal Forge MCP Vault client requires vault.path and the default user-secrets tokenFile.";
        }
        {
          assertion = !cfg.vault.enable || config.fmf.services.vault-agent.enable;
          message = "Crystal Forge MCP Vault client requires fmf.services.vault-agent.enable.";
        }
        {
          assertion = !cfg.vault.enable || cfg.vault.kvVersion != 2 || lib.hasInfix "/data/" cfg.vault.path;
          message = "Crystal Forge MCP client vault.path must include /data/ for KV v2.";
        }
      ];
      # The `opencode` command exports the token at start; opencode.json references it by name.
      # fmf.services.opencode-server picks the same file up through its environmentFiles default.
      home-manager.users.${cfg.user}.fmf.tools.agentic-ai = {
        runtimeEnvFiles.${cfg.envVar} = cfg.tokenFile;
        mcp.${cfg.name} = {
          type = "remote";
          inherit (cfg) url;
          enabled = true;
          oauth = false;
          headers.Authorization = "Bearer {env:${cfg.envVar}}";
        };
      };
    }
    (lib.mkIf cfg.vault.enable {
      # Reuse the existing user-secret renderer and copy service, as llama-cpp-client and strata-client do.
      # Only this file's template comes from the token's secret.
      fmf.services.user-secrets = {
        enable = true;
        users.${cfg.user}.files = ["crystal_forge_mcp_pat"];
      };
      fmf.services.vault-agent.services."user-secrets-${cfg.user}".secrets.file.files."${cfg.user}-crystal_forge_mcp_pat".text = lib.mkForce ''
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
