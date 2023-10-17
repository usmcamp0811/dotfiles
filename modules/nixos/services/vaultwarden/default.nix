{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.vaultwarden;
in
{
  options.campground.services.vaultwarden = with types; {
    enable = mkBoolOpt false "Enable Vaultwarden;";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/vaultwarden" "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
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

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
  };

  services.nginx = {
    virtualHosts."bitwarden.lan" = {
      # useACMEHost = "thalheim.io";
      # forceSSL = true;
      extraConfig = ''
        client_max_body_size 128M;
      '';
      locations."/" = {
        proxyPass = "http://localhost:3011";
        proxyWebsockets = true;
      };
      locations."/notifications/hub" = {
        proxyPass = "http://localhost:3012";
        proxyWebsockets = true;
      };
      locations."/notifications/hub/negotiate" = {
        proxyPass = "http://localhost:3011";
        proxyWebsockets = true;
      };
    };
  };
  campground.services.vault-agent.services.vaultwarden = {
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
      environment = {
        changeAction = "restart";
        template = 
          if cfg.kvVersion == "v1" then ''
            {{ with secret cfg.vault-path }}
            {{ range $key, $value := .Data }}
            {{ $key }}={{ $value }}
            {{ end }}
            {{ end }}
          '' else ''
            {{ with secret cfg.vault-path }}
            {{ range $key, $value := .Data.data }}  # Note the added .data for KV2
            {{ $key }}={{ $value }}
            {{ end }}
            {{ end }}
          '';
      };
    };
  };
};


}
