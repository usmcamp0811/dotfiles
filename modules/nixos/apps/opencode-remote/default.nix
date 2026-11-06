{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.opencode-remote;

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
  options.fmf.apps.opencode-remote = with types; {
    enable = mkEnableOption "wrapper that attaches the OpenCode TUI to a remote opencode-server";

    package = mkOption {
      type = package;
      default = pkgs.llm-agents.opencode;
      defaultText = literalExpression "pkgs.llm-agents.opencode";
      description = "OpenCode package. Keep it equal to the server's version.";
    };

    user = mkOption {
      type = strMatching "[a-z_][a-zA-Z0-9_-]*";
      default = config.fmf.user.name;
      defaultText = literalExpression "config.fmf.user.name";
      description = "User whose runtime secret directory holds the password. Must already exist.";
    };

    command = mkOpt (strMatching "[a-zA-Z0-9_-]+") "opencode-remote" "Name of the installed wrapper command (it does not shadow `opencode`).";

    url = mkOpt str "http://10.8.0.26:4096" "Server URL (vm-agent). The OPENCODE_REMOTE_URL environment variable overrides it per invocation.";

    username = mkOpt str "opencode" "HTTP basic auth user name; must match the server.";

    rootDir = mkOpt str "/home/${cfg.user}/code" "Directory *on the server* to open when the caller gives no --dir.";

    followCwd = mkBoolOpt false ''
      If the current directory is inside rootDir, open that directory instead. Only enable on
      hosts that see the same tree at the same path as the server (a shared mount).
    '';

    passwordFile =
      mkOpt str "/var/lib/vault/users/${cfg.user}/opencode_server_password"
      "Runtime user-readable password file written by fmf.services.user-secrets; keep the default.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasAttr cfg.user config.users.users;
        message = "fmf.apps.opencode-remote: user ${cfg.user} must already exist.";
      }
      {
        assertion = config.fmf.services.vault-agent.enable;
        message = "fmf.apps.opencode-remote requires fmf.services.vault-agent.enable (the password comes from user-secrets).";
      }
    ];

    environment.systemPackages = [wrapper];

    # The established per-user secret path: the same Vault KV and AppRole policy this host
    # already uses for its other user secrets (secret/campground/users/<user>, key below).
    fmf.services.user-secrets = {
      enable = true;
      users.${cfg.user}.files = ["opencode_server_password"];
    };
  };
}
