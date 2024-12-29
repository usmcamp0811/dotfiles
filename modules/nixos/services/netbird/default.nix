{ lib, config, pkgs, utils, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.netbird;
in {
  options.campground.services.netbird = with types; {
    enable = mkBoolOpt false "Enable Netbird;";
    oidc-domain =
      mkOpt str "authentik.lan.aicampground.com" "Domain for Netbird to use";
    netbird-domain = mkOpt str "netbird.aicampground.com" "Netbird Domain";
    port = mkOpt int 10001 "Port to use";
    turn-port = mkOpt int 3478 "Port for turn";
    client-id =
      mkOpt str "kLVxL9B0tZNwR8VYWWE8DHoXpvjLDnErpkgTEQDa" "Client ID";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/authentik"
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
                Username = "netbird";
                Password._secret = "/tmp/detsys-vault/coturn";
              }];

              Secret._secret = "/tmp/detsys-vault/turn_secret";
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
                  "/tmp/detsys-vault/netbird_authentik_password";
                Username = "netbird";
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
          passwordFile = "/tmp/detsys-vault/coturn";
          domain = cfg.netbird-domain;
        };
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
      ExecStart = lib.mkForce (utils.escapeSystemdExecArgs [
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
      netbird = {
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
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_SECRET_KEY }}{{ else }}{{ .Data.data.AUTHENTIK_SECRET_KEY }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "coturn" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_SECRET_KEY }}{{ else }}{{ .Data.data.AUTHENTIK_SECRET_KEY }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "turn_secret" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_SECRET_KEY }}{{ else }}{{ .Data.data.AUTHENTIK_SECRET_KEY }}{{ end }}{{ end }}
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
