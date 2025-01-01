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
  clientMode = { services.netbird.enable = true; };
  serverMode = mkIf (!cfg.client) {
    networking.firewall.allowedTCPPorts =
      [ cfg.port cfg.signal-port cfg.ui-port cfg.turn-port ];

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


        # Update the "coturn" secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/coturn > /var/lib/coturn/secret
        chown -R turnserver:turnserver /var/lib/coturn/
        chmod 640 /var/lib/coturn/secret
        chown turnserver:turnserver /var/lib/coturn/secret

        # Ensure /var/lib/netbird-mgmt exists with correct permissions
        mkdir -p /var/lib/netbird-mgmt
        # Update the "turn" secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/turn > /var/lib/netbird-mgmt/turn
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/coturn > /var/lib/netbird-mgmt/coturn_nb
        chown netbird:netbird /var/lib/netbird-mgmt/coturn_nb
        chmod 640 /var/lib/netbird-mgmt/turn
        chmod 640 /var/lib/netbird-mgmt/coturn_nb
        chown turnserver:netbird /var/lib/netbird-mgmt/turn
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
        enableNginx = lib.mkForce true;
        management = {
          enable = true;
          port = 33073;
          enableNginx = lib.mkForce true;
          oidcConfigEndpoint =
            "https://auth.aicampground.com/application/o/netbird/.well-known/openid-configuration";
          # "https://${cfg.oidc-domain}/application/o/netbird/.well-known/openid-configuration";
          domain = "netbird.aicampground.com";
          # turnDomain = cfg.netbird-domain;
          turnDomain = "turn.netbird.aicampground.com";
          # dnsDomain = "netbird.${cfg.netbird-domain}";
          dnsDomain = "dns.netbird.aicampground.com";
          singleAccountModeDomain = "netbird.aicampground.com";

          # singleAccountModeDomain = "netbird.${cfg.netbird-domain}";

          settings = {
            Signal = {
              Proto = "https";
              URI = "netbird.aicampground.com:443";
              Username = "";
              Password = null;
            };
            TURNConfig = {
              Turns = [{
                Proto = "udp";
                URI = "turn:turn.netbird.aicampground.com:3478";
                Username = "NetBird";
                Password._secret = "/var/lib/netbird-mgmt/coturn_nb";
              }];

              Secret._secret = "/var/lib/netbird-mgmt/turn";
            };

            DataStoreEncryptionKey = null;

            HttpConfig = {
              AuthAudience = cfg.client-id;
              AuthUserIDClaim = "sub";
              AuthIssuer =
                "https://auth.aicampground.com/application/o/netbird/";
              AuthKeysLocation =
                "https://auth.aicampground.com/application/o/netbird/jwks/";
              # AuthUserIDClaim = "";
              # IdpSignKeyRefreshEnabled = false;
            };

            IdpManagerConfig = {
              ManagerType = "authentik";
              ClientConfig = {
                Issuer = "https://auth.aicampground.com/application/o/netbird/";
                # "https://${cfg.oidc-domain}/application/o/netbird/";
                ClientID = cfg.client-id;
                TokenEndpoint =
                  "https://auth.aicampground.com/application/o/token/";
                # "https://${cfg.oidc-domain}/application/o/token/";
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
              Scope = "openid profile email offline_access api";
              # UseIDToken = false;
              AuthorizationEndpoint =
                "https://auth.aicampground.com/application/o/authorize/";
              # "https://${cfg.oidc-domain}/application/o/authorize/";
              TokenEndpoint =
                "https://auth.aicampground.com/application/o/token/";
              # "https://${cfg.oidc-domain}/application/o/token/";
              # RedirectURLs = [ "https://netbird.aicampground.com/callback" ];
            };
          };
        };

        signal = {
          enable = true;
          port = 10000;
          domain = "netbird.aicampground.com";
          enableNginx = lib.mkForce true;
        };

        dashboard = {
          enable = true;
          enableNginx = true;
          domain = "netbird.aicampground.com";
          managementServer = "https://netbird.aicampground.com";
          settings = {
            AUTH_AUTHORITY =
              "https://auth.aicampground.com/application/o/netbird/";
            # "https://${cfg.oidc-domain}/application/o/netbird/";
            AUTH_SUPPORTED_SCOPES = "openid profile email offline_access api";
            AUTH_AUDIENCE = cfg.client-id;
            AUTH_CLIENT_ID = cfg.client-id;
            USE_AUTH0 = "false";
          };
        };

        coturn = {
          enable = true;
          passwordFile = "/var/lib/coturn/secret";
          domain = cfg.netbird-domain;
        };
      };
    };
    services.nginx.virtualHosts.${cfg.netbird-domain} = {
      listen = [{
        addr = "0.0.0.0";
        port = 33073;
        ssl = false;
      }];
    };

    users.users.netbird = {
      name = "netbird";
      group = "netbird";
      isSystemUser = true;
      extraGroups = [ "turnserver" ];
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
        "${toString cfg.signal-port}"
        # Log to stdout
        "--log-file"
        "console"
        # Log level
        "--log-level"
        "DEBUG"
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
in
{
  options.campground.services.netbird = with types; {
    enable = mkBoolOpt false "Enable Netbird;";
    client = mkBoolOpt false "If we just need the client";

    oidc-domain = mkOpt str "auth.aicampground.com" "Domain for Netbird to use";
    netbird-domain = mkOpt str "netbird.aicampground.com" "Netbird Domain";
    port = mkOpt int 10001 "Port to use";
    ui-port = mkOpt int 10031 "Port to use";
    signal-port = mkOpt int 10000 "Port to use";
    turn-port = mkOpt int 3478 "Port for turn";
    client-id =
      mkOpt str "cDngatAca7vzV61toEzBSmqQCu7Z8YuhiTFRJH3U" "Client ID";

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

  config = mkIf cfg.enable { services.netbird.enable = true; } // serverMode;
}
