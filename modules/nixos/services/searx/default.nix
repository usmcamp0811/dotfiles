{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.searx;
  # Assuming the definition of `findEnabledServices` is correct and placed appropriately
  #
  # Assuming `self` is correctly defined in your broader context
  #
  # # Generate URLs for each enabled service
in
{
  options.campground.services.searx = with types; {
    enable = mkBoolOpt false "Enable an Searx;";
    port = mkOpt int 8081 "Port to Host the searx server on.";
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/searx"
      "The Vault path to the KV containing the Searx Secrets.";
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
    # campground.services = {
    #   traefik = {
    #     dynamicConfigOptions = {
    #       http.routers.searx = {
    #         rule = "Host(`searx.aicampground.com`)";
    #         entryPoints = [ "web" ];
    #         service = "searx";
    #       };
    #
    #       http.services.searx = {
    #         loadBalancer.servers = searxURLs;
    #       };
    #     };
    #   };
    # };
    networking.firewall.allowedTCPPorts = [ cfg.port ];
    services = {
      searx = {
        enable = true;
        environmentFile = "/var/lib/vault/searx.env";
        package = pkgs.searxng;
        settings = {
          runInUwsgi = true;
          server.port = cfg.port;
          server.bind_address = "0.0.0.0";
          server.secret_key = "@SEARX_SECRET_KEY@";
          formats = [ "json" "html" ];
        };
      };
    };

    systemd.services.copy-searx-env = {
      description = "Copy Searx environment variables";
      serviceConfig = { Type = "oneshot"; };
      script = ''
        cp /tmp/detsys-vault/searx.env /var/lib/vault/searx.env
        chmod 600 /var/lib/vault/searx.env
        chown searx:searx /var/lib/vault/searx.env
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "searx.service" ];
    };

    campground.services.vault-agent.services.copy-searx-env = {
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
            "searx.env" = {
              text = ''
                SEARX_SECRET_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SEARX_SECRET_KEY }}{{ else }}{{ .Data.data.SEARX_SECRET_KEY }}{{ end }}{{ end }}
              '';
              permissions = "0600"; # Make the script executable
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
