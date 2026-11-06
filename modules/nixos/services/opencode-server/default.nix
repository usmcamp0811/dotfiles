{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.opencode-server;

  # The password reaches the process as OPENCODE_SERVER_PASSWORD, from the EnvironmentFile that
  # the Vault Agent sidecar renders (the navidrome pattern). opencode treats an empty password
  # as "no authentication", and systemd parses quotes/backslashes in env files, so the launcher
  # refuses to start unless the value is present, long enough and made of plain characters only.
  launcher = pkgs.writeShellScript "opencode-server-start" ''
    set -eu

    # Same tools an interactive login of the user has (git, rg, nix, ...).
    export PATH="/etc/profiles/per-user/${cfg.user}/bin:/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

    password="''${OPENCODE_SERVER_PASSWORD:-}"
    if [ "''${#password}" -lt ${toString cfg.minPasswordLength} ]; then
      echo "opencode-server: Vault password missing or shorter than ${toString cfg.minPasswordLength} characters; refusing to start without authentication" >&2
      exit 1
    fi
    case "$password" in
      *[!A-Za-z0-9._~+/=-]*)
        echo "opencode-server: password may only contain A-Za-z0-9 . _ ~ + / = - (use e.g. openssl rand -hex 32)" >&2
        exit 1
        ;;
    esac
    export OPENCODE_SERVER_USERNAME=${escapeShellArg cfg.username}

    # Provider credentials read at process start (never from the Nix store). A missing file
    # must not stop unrelated providers from working.
    ${concatStringsSep "\n" (mapAttrsToList (name: file: ''
        if [ -r ${escapeShellArg file} ]; then
          export ${name}="$(< ${escapeShellArg file})"
        fi
      '')
      cfg.environmentFiles)}

    exec ${cfg.package}/bin/opencode serve \
      --hostname ${escapeShellArg cfg.address} \
      --port ${toString cfg.port} \
      ${escapeShellArgs cfg.extraArgs}
  '';
in {
  options.fmf.services.opencode-server = with types; {
    enable = mkEnableOption "OpenCode headless server (opencode serve) protected by HTTP basic auth";

    package = mkOption {
      type = package;
      default = pkgs.llm-agents.opencode;
      defaultText = literalExpression "pkgs.llm-agents.opencode";
      description = "OpenCode package. Keep it equal to the clients' version.";
    };

    user = mkOption {
      type = strMatching "[a-z_][a-zA-Z0-9_-]*";
      default = config.fmf.user.name;
      defaultText = literalExpression "config.fmf.user.name";
      description = "Account the server (and every command the agent runs) executes as. Must already exist.";
    };

    rootDir =
      mkOpt str "/home/${cfg.user}/code"
      "Working directory of the server: the directory clients land in unless they ask for another one.";

    address = mkOpt str "0.0.0.0" "Address to listen on.";
    port = mkOpt port 4096 "TCP port to listen on.";
    openFirewall = mkBoolOpt false "Whether to open the firewall for the server port.";

    username = mkOpt str "opencode" "HTTP basic auth user name (OPENCODE_SERVER_USERNAME).";
    minPasswordLength = mkOpt ints.positive 16 "The server refuses to start with a shorter password.";

    environmentFiles = mkOption {
      type = attrsOf str;
      default = optionalAttrs config.fmf.services.llama-cpp-client.enable {
        LLAMA_CPP_API_KEY = config.fmf.services.llama-cpp-client.apiKeyFile;
      };
      defaultText = literalExpression "{ LLAMA_CPP_API_KEY = <llama-cpp-client apiKeyFile>; } when the llama.cpp client is enabled";
      description = ''
        Environment variable name -> runtime file whose content becomes its value, read when the
        server starts. Needed because the server, not the attached client, talks to the model
        providers, so it needs their credentials.
      '';
    };

    extraArgs = mkOpt (listOf str) [] "Extra arguments for `opencode serve`.";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/opencode-server"
      "The Vault path to the KV holding the server password (key: password).";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasAttr cfg.user config.users.users;
        message = "fmf.services.opencode-server: user ${cfg.user} must already exist.";
      }
      {
        assertion = hasPrefix "/" cfg.rootDir;
        message = "fmf.services.opencode-server: rootDir must be an absolute path.";
      }
      {
        assertion = config.fmf.services.vault-agent.enable;
        message = "fmf.services.opencode-server requires fmf.services.vault-agent.enable.";
      }
    ];

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];

    systemd.services.opencode-server = {
      description = "OpenCode headless server";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = [
        "network-online.target"
        # The user's opencode config (home-manager) and runtime secret copies must exist first.
        "home-manager-${cfg.user}.service"
        "user-secrets-${cfg.user}.service"
      ];
      # rootDir may be a separate mount (virtiofs share, ...).
      unitConfig.RequiresMountsFor = [cfg.rootDir];
      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = cfg.rootDir;
        ExecStart = launcher;
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
      };
    };

    fmf.services.vault-agent.services.opencode-server = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };
      secrets.environment.templates.opencode-server = {
        text = ''
          OPENCODE_SERVER_PASSWORD={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.password }}{{ else }}{{ .Data.data.password }}{{ end }}{{ end }}
        '';
      };
    };
  };
}
