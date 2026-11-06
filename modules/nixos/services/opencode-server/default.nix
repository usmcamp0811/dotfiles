{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.fmf.services.opencode-server;
  vaultDefaults = config.fmf.services.vault-agent.settings.vault or {};
  vaultPasswordFile = config.fmf.services.vault-agent.services.opencode-server.secrets.file.files.password.path;
  passwordFile =
    if cfg.vault.enable
    then vaultPasswordFile
    else cfg.passwordFile;

  # opencode treats an empty OPENCODE_SERVER_PASSWORD as "no authentication", so the
  # launcher refuses to start unless the password is present and sane.
  launcher = pkgs.writeShellScript "opencode-server-start" ''
    set -eu

    # Same tools an interactive login of the user has (git, rg, nix, ...).
    export PATH="/etc/profiles/per-user/${cfg.user}/bin:/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

    password_file=${escapeShellArg passwordFile}
    if [ ! -r "$password_file" ]; then
      echo "opencode-server: password file $password_file is missing or unreadable" >&2
      exit 1
    fi
    password="$(< "$password_file")"
    case "$password" in
      *[[:space:]]*) echo "opencode-server: password must not contain whitespace" >&2; exit 1 ;;
    esac
    if [ "''${#password}" -lt ${toString cfg.minPasswordLength} ]; then
      echo "opencode-server: password shorter than ${toString cfg.minPasswordLength} characters, refusing to start unauthenticated or weakly protected" >&2
      exit 1
    fi
    export OPENCODE_SERVER_PASSWORD="$password"
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
  options.fmf.services.opencode-server = {
    enable = mkEnableOption "OpenCode headless server (opencode serve) protected by HTTP basic auth";

    package = mkOption {
      type = types.package;
      default = pkgs.llm-agents.opencode;
      defaultText = literalExpression "pkgs.llm-agents.opencode";
      description = "OpenCode package. Keep it equal to the clients' version.";
    };

    user = mkOption {
      type = types.strMatching "[a-z_][a-zA-Z0-9_-]*";
      default = config.fmf.user.name;
      defaultText = literalExpression "config.fmf.user.name";
      description = "Account the server (and every command the agent runs) executes as. Must already exist.";
    };

    rootDir = mkOption {
      type = types.str;
      default = "/home/${cfg.user}/code";
      defaultText = literalExpression ''"/home/''${config.fmf.services.opencode-server.user}/code"'';
      description = "Working directory of the server: the directory clients land in unless they ask for another one.";
    };

    address = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address to listen on.";
    };

    port = mkOption {
      type = types.port;
      default = 4096;
      description = "TCP port to listen on.";
    };

    openFirewall = mkEnableOption "opening the server port in the host firewall";

    username = mkOption {
      type = types.str;
      default = "opencode";
      description = "HTTP basic auth user name (OPENCODE_SERVER_USERNAME).";
    };

    minPasswordLength = mkOption {
      type = types.ints.positive;
      default = 16;
      description = "The server refuses to start with a shorter password.";
    };

    passwordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime file holding the password (outside the Nix store). Only used when vault.enable is false.";
    };

    environmentFiles = mkOption {
      type = types.attrsOf types.str;
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

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra arguments for `opencode serve`.";
    };

    vault = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Render the password with Vault Agent (the service-side sidecar pattern).";
      };
      path = mkOption {
        type = types.str;
        default = "secret/campground/opencode-server";
        description = "Vault API path; include /data/ for KV v2. Must be readable by the host's AppRole (policy opencode-server-read).";
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
          message = "opencode-server user ${cfg.user} must already exist.";
        }
        {
          assertion = hasPrefix "/" cfg.rootDir;
          message = "opencode-server rootDir must be an absolute path.";
        }
        {
          assertion = cfg.vault.enable || (cfg.passwordFile != null && hasPrefix "/" cfg.passwordFile && !(hasPrefix "/nix/store/" cfg.passwordFile));
          message = "opencode-server needs vault.enable or an absolute passwordFile outside /nix/store.";
        }
        {
          assertion = !(cfg.vault.enable && cfg.passwordFile != null);
          message = "Select either opencode-server vault.enable or passwordFile, not both.";
        }
        {
          assertion = !cfg.vault.enable || cfg.vault.path != "";
          message = "Set fmf.services.opencode-server.vault.path.";
        }
        {
          assertion = !cfg.vault.enable || config.fmf.services.vault-agent.enable;
          message = "opencode-server Vault authentication requires fmf.services.vault-agent.enable.";
        }
        {
          assertion = !cfg.vault.enable || all (v: v != "") [(vaultDefaults.address or "") (vaultDefaults.role-id or "") (vaultDefaults.secret-id or "")];
          message = "opencode-server Vault Agent requires a Vault address and AppRole role-id/secret-id file paths in fmf.services.vault-agent.settings.vault.";
        }
        {
          assertion = !cfg.vault.enable || cfg.vault.kvVersion != 2 || hasInfix "/data/" cfg.vault.path;
          message = "opencode-server vault.path must be the KV v2 API path (including /data/).";
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
    }

    (mkIf cfg.vault.enable {
      # Service-side Vault Agent sidecar, as for llama-cpp: it renders the file into the
      # service's private /tmp, owned by the service user, and restarts the service on change.
      # Configure auto_auth explicitly; registering a template alone leaves it empty.
      fmf.services.vault-agent.services.opencode-server = {
        settings = {
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
        secrets.file.files.password = {
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
      };
    })
  ]);
}
