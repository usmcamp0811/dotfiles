{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.netbird;
  # Quotes an argument for use in Exec* service lines.
  # systemd accepts "-quoted strings with escape sequences, toJSON produces
  # a subset of these.
  # Additionally we escape % to disallow expansion of % specifiers. Any lone ;
  # in the input will be turned it ";" and thus lose its special meaning.
  # Every $ is escaped to $$, this makes it unnecessary to disable environment
  # substitution for the directive.
  escapeSystemdExecArg = arg:
    let
      s =
        if builtins.isPath arg then
          "${arg}"
        else if builtins.isString arg then
          arg
        else if builtins.isInt arg || builtins.isFloat arg then
          toString arg
        else
          throw "escapeSystemdExecArg only allows strings, paths and numbers";
    in
    replaceStrings [ "%" "$" ] [ "%%" "$$" ] (builtins.toJSON s);

  # Quotes a list of arguments into a single string for use in a Exec*
  # line.
  escapeSystemdExecArgs = concatMapStringsSep " " escapeSystemdExecArg;
in
{
  options.campground.services.netbird = with types; {
    enable = mkBoolOpt false "Enable Netbird;";
    oidc-domain =
      mkOpt str "authentik.lan.aicampground.com" "Domain for Netbird to use";
    netbird-domain = mkOpt str "netbird.aicampground.com" "Netbird Domain";
    port = mkOpt int 10001 "Port to use";
    ui-port = mkOpt int 10031 "Port to use";
    turn-port = mkOpt int 3478 "Port for turn";
    client-id =
      mkOpt str "kLVxL9B0tZNwR8VYWWE8DHoXpvjLDnErpkgTEQDa" "Client ID";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/netbird"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    systemd.services.netbirdSecrets = {
      description = "Set up Netbird Secrets with Correct Permissions";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        # Ensure /var/lib/netbird exists with correct permissions
        mkdir -p /var/lib/netbird/coturn
        mkdir -p /var/lib/coturn
        chmod 750 /var/lib/netbird
        chmod 750 /var/lib/coturn

        # Update the "turn" secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/turn > /var/lib/netbird/turn
        chmod 640 /var/lib/netbird/turn
        chown netbird:netbird /var/lib/netbird/turn

        # Update the "coturn" secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/coturn > /var/lib/coturn/secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/coturn > /var/lib/netbird/coturn_nb
        chown -R turnserver:turnserver /var/lib/coturn/
        chown netbird:netbird /var/lib/netbird/coturn_nb
        chmod 640 /var/lib/netbird/coturn_nb
        chmod 640 /var/lib/coturn/secret
        chown turnserver:turnserver /var/lib/coturn/secret

        # Ensure /var/lib/netbird-mgmt exists with correct permissions
        mkdir -p /var/lib/netbird-mgmt
        chmod 750 /var/lib/netbird-mgmt
        chown -R netbird:netbird /var/lib/netbird-mgmt

        # Update the "netbird_authentik_password" secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/netbird_authentik_password > /var/lib/netbird-mgmt/netbird_authentik_password
        chmod 600 /var/lib/netbird-mgmt/netbird_authentik_password
        chown netbird:netbird /var/lib/netbird-mgmt/netbird_authentik_password
      '';

      wantedBy = [ "multi-user.target" ];
      before = [
        "netbird-management.service"
        "netbird-signal.service"
        "netbird-dashboard.service"
        "coturn.service"
      ];
    };
    services.netbird = {
      enable = true;

      server = {
        management = {
          enable = true;
          port = cfg.port;
          oidcConfigEndpoint =
            "https://${cfg.oidc-domain}/application/o/netbird/.well-known/openid-configuration";
          domain = cfg.netbird-domain;
          turnDomain = cfg.netbird-domain;
          dnsDomain = "net.${cfg.netbird-domain}";
          singleAccountModeDomain = "net.${cfg.netbird-domain}";

          settings = {
            TURNConfig = {
              Turns = [{
                Proto = "udp";
                URI = "turn:${cfg.netbird-domain}:${toString cfg.turn-port}";
                Username = "NetBird";
                Password._secret = "/var/lib/netbird/coturn";
              }];

              Secret._secret = "/var/lib/netbird/turn";
            };

            DataStoreEncryptionKey = null;

            HttpConfig = {
              AuthAudience = cfg.client-id;
              AuthUserIDClaim = "sub";
            };

            IdpManagerConfig = {
              ManagerType = "authentik";
              ClientConfig = {
                Issuer = "https://${cfg.oidc-domain}/application/o/netbird/";
                ClientID = cfg.client-id;
                TokenEndpoint =
                  "https://${cfg.oidc-domain}/application/o/token/";
                ClientSecret = "";
              };
              ExtraConfig = {
                Password._secret =
                  "/var/lib/netbird-mgmt/netbird_authentik_password";
                Username = "NetBird";
              };
            };

            PKCEAuthorizationFlow.ProviderConfig = {
              Audience = cfg.client-id;
              ClientID = cfg.client-id;
              ClientSecret = "";
              AuthorizationEndpoint =
                "https://${cfg.oidc-domain}/application/o/authorize/";
              TokenEndpoint = "https://${cfg.oidc-domain}/application/o/token/";
              RedirectURLs = [ "http://localhost:53000" ];
            };
          };
        };

        signal = {
          enable = true;
          port = 10000;
          domain = cfg.netbird-domain;
        };

        dashboard = {
          enable = true;
          enableNginx = lib.mkForce true;
          domain = cfg.netbird-domain;
          managementServer = "https://${cfg.netbird-domain}";
          settings = {
            AUTH_AUTHORITY =
              "https://${cfg.oidc-domain}/application/o/netbird/";
            AUTH_SUPPORTED_SCOPES = "openid profile email offline_access api";
            AUTH_AUDIENCE = cfg.client-id;
            AUTH_CLIENT_ID = cfg.client-id;
          };
        };

        coturn = {
          enable = true;
          passwordFile = "/var/lib/coturn/secret";
          domain = cfg.netbird-domain;
        };
      };
    };
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.netbird-domain} = {
        listen = [{
          addr = "0.0.0.0";
          port = cfg.ui-port;
          ssl = false;
        }];
      };
    };

    users.users.netbird = {
      name = "netbird";
      group = "netbird";
      isSystemUser = true;
    };
    users.groups.netbird = { };

    systemd.services.netbird-management.serviceConfig = {
      User = "netbird";
      Group = "netbird";
    };
    systemd.services.netbird-signal.serviceConfig = {
      User = "netbird";
      Group = "netbird";
      ExecStart = lib.mkForce (escapeSystemdExecArgs [
        (lib.getExe' pkgs.netbird "netbird-signal")
        "run"
        # Port to listen on
        "--port"
        "10000"
        # Log to stdout
        "--log-file"
        "console"
        # Log level
        "--log-level"
        "INFO"
        "--metrics-port"
        "9091"
      ]);
    };

    campground.services.vault-agent.services = {
      netbirdSecrets = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets = {
          file = {
            files = {
              "netbird_authentik_password" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.authentik_user_password  }}{{ else }}{{ .Data.data.authentik_user_password }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "coturn" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.coturn }}{{ else }}{{ .Data.data.coturn }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "turn" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.turn }}{{ else }}{{ .Data.data.turn }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
            };
          };
        };
      };
    };
  };
}
