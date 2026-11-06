{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.fmf.services.opencode-server-client;
  defaultPasswordFile = "/var/lib/vault/users/${cfg.user}/opencode_server_password";

  wrapper = pkgs.writeShellScriptBin cfg.command ''
    set -eu

    url="''${OPENCODE_REMOTE_URL:-${cfg.url}}"
    password_file=${escapeShellArg cfg.passwordFile}

    if [ ! -r "$password_file" ]; then
      echo "${cfg.command}: cannot read $password_file" >&2
      echo "${cfg.command}: the Vault-rendered password is missing (check: systemctl status user-secrets-${cfg.user})" >&2
      exit 1
    fi
    OPENCODE_SERVER_PASSWORD="$(< "$password_file")"
    export OPENCODE_SERVER_PASSWORD
    export OPENCODE_SERVER_USERNAME=${escapeShellArg cfg.username}

    # Directory on the *server*. An explicit --dir from the caller wins.
    dir=${escapeShellArg cfg.rootDir}
    ${optionalString cfg.followCwd ''
      # The server sees this tree at the same path, so stay in the current project.
      case "$PWD/" in
        "$dir"/*) dir="$PWD" ;;
      esac
    ''}
    for arg in "$@"; do
      case "$arg" in
        --dir|--dir=*) exec ${cfg.package}/bin/opencode attach "$url" "$@" ;;
      esac
    done

    exec ${cfg.package}/bin/opencode attach "$url" --dir "$dir" "$@"
  '';
in {
  options.fmf.services.opencode-server-client = {
    enable = mkEnableOption "wrapper that attaches the OpenCode TUI to a remote opencode-server";

    package = mkOption {
      type = types.package;
      default = pkgs.llm-agents.opencode;
      defaultText = literalExpression "pkgs.llm-agents.opencode";
      description = "OpenCode package. Keep it equal to the server's version.";
    };

    user = mkOption {
      type = types.strMatching "[a-z_][a-zA-Z0-9_-]*";
      default = config.fmf.user.name;
      defaultText = literalExpression "config.fmf.user.name";
      description = "User whose runtime secret directory holds the password. Must already exist.";
    };

    command = mkOption {
      type = types.strMatching "[a-zA-Z0-9_-]+";
      default = "opencode-remote";
      description = "Name of the installed wrapper command (it does not shadow `opencode`).";
    };

    url = mkOption {
      type = types.str;
      example = "http://10.8.0.26:4096";
      description = "Server URL. The OPENCODE_REMOTE_URL environment variable overrides it per invocation.";
    };

    username = mkOption {
      type = types.str;
      default = "opencode";
      description = "HTTP basic auth user name; must match the server.";
    };

    rootDir = mkOption {
      type = types.str;
      default = "/home/${cfg.user}";
      defaultText = literalExpression ''"/home/''${config.fmf.services.opencode-server-client.user}"'';
      description = "Directory *on the server* to open when the caller gives no --dir.";
    };

    followCwd = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If the current directory is inside rootDir, open that directory instead. Only enable on
        hosts that see the same tree at the same path as the server (a shared mount).
      '';
    };

    passwordFile = mkOption {
      type = types.str;
      default = defaultPasswordFile;
      defaultText = literalExpression ''"/var/lib/vault/users/<user>/opencode_server_password"'';
      description = "Runtime user-readable password file, outside the Nix store. With Vault enabled, keep the default.";
    };

    vault = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      path = mkOption {
        type = types.str;
        default = "";
        example = "secret/campground/data/opencode-server";
        description = "Vault API path; include /data/ for KV v2.";
      };
      field = mkOption {
        type = types.str;
        default = "password";
      };
      kvVersion = mkOption {
        type = types.enum [1 2];
        default = 2;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = hasAttr cfg.user config.users.users;
          message = "opencode-server client user must already exist.";
        }
        {
          assertion = hasPrefix "/" cfg.passwordFile && !(hasPrefix "/nix/store/" cfg.passwordFile);
          message = "opencode-server client passwordFile must be an absolute runtime path outside /nix/store.";
        }
        {
          assertion = !cfg.vault.enable || (cfg.vault.path != "" && cfg.passwordFile == defaultPasswordFile);
          message = "opencode-server Vault client requires vault.path and the default user-secrets passwordFile.";
        }
        {
          assertion = !cfg.vault.enable || config.fmf.services.vault-agent.enable;
          message = "opencode-server Vault client requires fmf.services.vault-agent.enable.";
        }
        {
          assertion = !cfg.vault.enable || cfg.vault.kvVersion != 2 || hasInfix "/data/" cfg.vault.path;
          message = "opencode-server client vault.path must include /data/ for KV v2.";
        }
      ];
      environment.systemPackages = [wrapper];
    }

    (mkIf cfg.vault.enable {
      # Reuse the existing user-secret renderer and copy service (as llama-cpp-client does);
      # only this file's template comes from the dedicated shared secret.
      fmf.services.user-secrets = {
        enable = true;
        users.${cfg.user}.files = ["opencode_server_password"];
      };
      fmf.services.vault-agent.services."user-secrets-${cfg.user}".secrets.file.files."${cfg.user}-opencode_server_password".text = mkForce ''
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
