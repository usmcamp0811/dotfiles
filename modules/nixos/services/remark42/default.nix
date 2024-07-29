{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.remark42;
  # Assuming the definition of `findEnabledServices` is correct and placed appropriately
  #
  # Assuming `self` is correctly defined in your broader context
  #
  # # Generate URLs for each enabled service
in {
  options.campground.services.remark42 = with types; {
    enable = mkBoolOpt false "Enable an Searx;";
    port = mkOpt int 8081 "Port to Host the remark42 server on.";
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/remark42"
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
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    users.users.remark42 = {
      isSystemUser = true;
      group = "remark42";
      home = "/var/lib/remark42";
      createHome = true;
    };

    systemd.services.remark42-campground-blog = {
      enable = true;
      package = pkgs.remark42;
      description = "Comment engine for blog.aicampground.com";
      environment = {
        REMARK_URL = "https://blog.aicampground.com";
        STORE_BOLT_PATH = "/var/lib/remark42/db";
        REMARK_PORT = "12381";
        SITE = "blog.aicampground.com";
        EMOJI = "true";
      };
      serviceConfig = {
        ExecStart = "${pkgs.remark42}/bin/remark42 server";
        Restart = "always";
        RestartSec = 30;
        StandardOutput = "syslog";
        WorkingDirectory = "/var/lib/remark42/assets";
        User = "remark42";
        Group = "remark42";
      };
    };

    campground.services.vault-agent.services.copy-remark42-env = {
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
        environment.templates = {
          secret-service-env = {
            text = ''
              {{ with secret "secret/campground" }}
              YANKEE_WHITE="{{ .Data.value }}"
              {{ end }}
            '';
          };
        };
      };
    };
  };
}
