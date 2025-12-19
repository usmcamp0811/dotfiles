{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.netmaker;
in {
  options.fmf.services.netmaker = with types; {
    enable = mkBoolOpt false "Netmaker";
    server_name =
      mkOpt str "campground"
      "This is the public, resolvable DNS name of the MQ Broker.";
    server_host =
      mkOpt str "" "The public IP of the server where the machine is running.";
    coredns_addr = mkOpt str "" "The public IP of the CoreDNS server.";
    api_port = mkOpt int 8081 "Sets the port for the API on the server.";
    stun_list =
      mkOpt str
      "stun1.netmaker.io:3478,stun2.netmaker.io:3478,stun1.l.google.com:19302,stun2.l.google.com:19302"
      "Stun list";
    nm_domain = mkOpt str "nm.lucas.lan" "toplevel domain";
    # broker_endpoint = mkOpt str "wss://broker.${cfg.nm_domain}" "broker endpoint url";
    broker_endpoint = mkOpt str "wss://localhost" "broker endpoint url";
    server_api_conn_string =
      mkOpt str "api.${cfg.nm_domain}:443" "server api con string";
    server_http_host =
      mkOpt str "api.${cfg.nm_domain}"
      "Should be the same as SERVER_API_CONN_STRING minus the port.";
    master_key =
      mkOpt str "secretkey" "The admin master key for accessing the API.";

    cors_allowed_origin =
      mkOpt str "*" "The 'allowed origin' for API requests.";
    rest_backend = mkBoolOpt true "Enables the REST backend.";
    dns_mode = mkBoolOpt false "Enables DNS Mode.";

    database = mkOption {
      type = enum ["postgres" "sqlite" "rqlite"];
      default = "postgres";
      description = "Specify db type to connect with.";
    };
    sql_conn =
      mkOpt str "postgres://netmaker@/netmaker?host=/run/postgresql/"
      "Specify the necessary string to connect with your SQL database.";
    sql_host = mkOpt str "127.0.0.1" "Host where the SQL database is running.";
    sql_port = mkOpt int 5432 "Port the SQL database is running on.";
    sql_db = mkOpt str "netmaker" "DB to use in SQL database.";

    rce = mkBoolOpt false "Remote Code Execution feature.";
    display_keys =
      mkBoolOpt true "If 'on', will display key values of 'access keys'.";
    node_id = mkOpt str "" "Used for HA configurations of the server.";
    telemetry = mkBoolOpt false "If 'on', sends anonymous telemetry data.";
    mq_host = mkOpt str "" "The address of the MQ server.";
    host_network =
      mkBoolOpt false "Whether or not host networking is turned on.";
    manage_iptables =
      mkBoolOpt true "Allows Netmaker to manage iptables locally.";
    port_forward_services =
      mkOpt str "" "Comma-separated list of services for port forwarding.";
    verbosity = mkOpt int 0 "Specify the level of logging on the server.";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/netmaker"
      "The Vault path to the KV containing the k0s secrets.";
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.fmf.netmaker-ui
      pkgs.netmaker
    ]; # Ensure netmaker package is available

    # services.nginx = {
    #   enable = true;
    #   # recommendedGzipSettings = true;
    #   # recommendedOptimisationSettings = true;
    #   # recommendedProxySettings = true;
    #   # recommendedTlsSettings = false; # Since we're not using SSL/TLS yet
    #
    #   virtualHosts = {
    #     "dashboard.nm.webb.lan" = {
    #       forceSSL = false; # Not using SSL
    #       listen = [{ addr = "0.0.0.0"; port = 80; }];
    #       extraConfig = ''
    #         location / {
    #           root ${pkgs.fmf.netmaker-ui};
    #           add_header Access-Control-Allow-Origin *.$baseDomain;
    #           add_header X-XSS-Protection "1; mode=block";
    #           add_header X-Frame-Options "SAMEORIGIN";
    #           add_header X-Robots-Tag "none";
    #           server_tokens off;
    #         }
    #       '';
    #     };
    #     "broker.nm.webb.lan" = {
    #       forceSSL = false;
    #       listen = [{ addr = "0.0.0.0"; port = 80; }];
    #       extraConfig = ''
    #         location / {
    #           proxy_pass http://localhost:8883;
    #           proxy_http_version 1.1;
    #           proxy_set_header Upgrade $http_upgrade;
    #           proxy_set_header Connection "upgrade";
    #         }
    #       '';
    #     };
    #   };
    # };

    # Use Caddy to reverse proxy
    services.caddy = {
      enable = true;
      # group = "acme";

      virtualHosts."http://dashboard.nm.lucas.lan" = {
        # useACMEHost = "nm.gio.ninja";
        extraConfig = ''
          header {
              Access-Control-Allow-Origin *.nm.lucas.lan
              Strict-Transport-Security "max-age=31536000;"
              X-XSS-Protection "1; mode=block"
              X-Frame-Options "SAMEORIGIN"
              X-Robots-Tag "none"
              -Server
          }
          root * ${pkgs.fmf.netmaker-ui}
          file_server
          reverse_proxy http://localhost
        '';
      };
      virtualHosts."http://broker.nm.lucas.lan" = {
        # useACMEHost = "nm.gio.ninja";
        extraConfig = ''
          reverse_proxy http://localhost:8883
        '';
      };

      virtualHosts."http://api.nm.lucas.lan" = {
        # useACMEHost = "nm.gio.ninja";
        extraConfig = ''
          reverse_proxy http://localhost:8081
        '';
      };
    };

    users.users.netmaker = {
      isNormalUser = false;
      isSystemUser = true;
      description = "Netmaker user";
      group = "netmaker";
      extraGroups = [
        "netmaker"
      ]; # Optional if you want the user to be in additional groups
      home = "/var/lib/netmaker";
    };
    users.groups.netmaker = {};

    systemd.tmpfiles.rules = ["d /var/lib/netmaker 0755 netmaker netmaker -"];

    fmf.services.postgresql = {
      enable = true;
      authentication = [
        "local netmaker netmaker trust"
        "local postgres netmaker trust"
        "host netmaker netmaker 127.0.0.1/32 trust"
      ];
      databases = [
        {
          name = "netmaker";
          user = "netmaker";
        }
      ];
    };

    networking.firewall = {
      allowedTCPPorts = [
        # Caddy Proxy
        80
        443
        # TURN Server
        3479
        8089
      ];
      allowedUDPPorts = [
        51821 # Wireguard
      ];
    };

    # Setup Mosquitto MQTT message broker
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          port = 8883;
          users.netmaker.passwordFile = "/var/lib/vault/mq.pass";
          settings = {
            protocol = "websockets";
            allow_anonymous = false;
          };
        }
        {
          port = 1883;
          users.netmaker.passwordFile = "/var/lib/vault/mq.pass";
          settings = {
            protocol = "websockets";
            allow_anonymous = false;
          };
        }
      ];
    };

    systemd.services.netmaker = {
      description = "Netmaker Wireguard Mesh Network";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Restart = "always";
        User = "root";
      };
      environment = {
        APIHOST = "${cfg.server_host}";
        APIPORT = "${toString cfg.api_port}";
        ALLOWEDORIGIN = "${cfg.cors_allowed_origin}";
        RESTBACKEND = "${boolToString cfg.rest_backend}";
        DNSMODE = "${boolToString cfg.dns_mode}";
        SQL_CONN = "${cfg.sql_conn}";
        SQL_HOST = "${cfg.sql_host}";
        DISABLEREMOTEIPCHECK = "false";
        VERBOSITY = "${toString cfg.verbosity}";
        DATABASE = "${cfg.database}";
        DISPLAYKEYS = "${boolToString cfg.display_keys}";
        MANAGEIPTABLES = "${boolToString cfg.manage_iptables}";
        PORTFORWARDSERVICES = "${cfg.port_forward_services}";
        HOSTNETWORK = "${boolToString cfg.host_network}";
        TELEMETRY = "${boolToString cfg.telemetry}";
        MQ_HOST = "${cfg.mq_host}";
        STUN_LIST = "${cfg.stun_list}";
        BROKER_ENDPOINT = "${cfg.broker_endpoint}";
        SERVER_NAME = "${cfg.nm_domain}";
        SERVER_API_CONN_STRING = "${cfg.server_api_conn_string}";
        SERVER_HTTP_HOST = "${cfg.server_http_host}";
      };
      script = ''
        ${pkgs.netmaker}/bin/netmaker
      '';
    };

    systemd.services.copyMQpass = {
      description = "Copy Pass for MQ to a file";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      wantedBy = ["mosquitto.service"];
      script = ''
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/passwordFile /var/lib/vault/mq.pass
        chown mosquitto:mosquitto /var/lib/vault/mq.pass
      '';
    };

    fmf.services.vault-agent.services.netmaker = {
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
      secrets = {
        environment.templates = {
          rkvm = {
            text = ''
              {{ with secret "${cfg.vault-path}" }}
              MASTER_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.masterkey }}{{ else }}{{ .Data.data.masterkey }}{{ end }}{{ end }}
              SQL_PASS={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.sql_pass }}{{ else }}{{ .Data.data.sql_pass }}{{ end }}{{ end }}
              SQL_USER={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.sql_user }}{{ else }}{{ .Data.data.sql_user }}{{ end }}{{ end }}
              {{ end }}
            '';
          };
        };
      };
    };
    fmf.services.vault-agent.services.copyMQpass = {
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
      secrets = {
        file = {
          files = {
            "passwordFile" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.mosquitto_pass }}{{ else }}{{ .Data.data.mosquitto_pass }}{{ end }}{{ end }}'';
              permissions = "0600"; # Make the script executable
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
