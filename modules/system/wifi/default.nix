{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let 
  cfg = config.campground.system.wifi;
in
{
# Save Wifi Passwords in Vault with the SSID as the Key to the KV store
  options.campground.system.wifi = with types; {
    enable = mkBoolOpt false "Whether or not to enable Wifi.";
    role-id = mkOpt str "/var/lib/vault/wifi/role-id" "Absolute path to the Vault role-id";
    secret-id = mkOpt str "/var/lib/vault/wifi/secret-id" "Absolute path to the Vault secret-id";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    networks = mkOption {
      type = attrsOf (submodule {
        options = {
          ssid = mkOption {
            type = str;
            description = "The SSID of the WiFi network.";
          };
        };
      });
      default = {};
      description = "A list of WiFi networks to connect to.";
    };
  };
  config = mkIf cfg.enable {
    systemd.services.wifi_passwords = {
      description = "Set/update all Wifi Passwords";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/wifi-passwords";
        Type = "oneshot";
      };
    };
    campground.services.vault-agent.services.wifi_passwords = {
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
            "wifi-passwords" = {
              text = builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: network: ''
                #!/bin/sh
                SSID="${name}"
                PASSWORD={{ with secret "secret/campground/wifi" }}{{ .Data.${name} }}{{ end }}
                if ! ${pkgs.networkmanager}/bin/nmcli con show | grep -q $SSID; then
                  ${pkgs.networkmanager}/bin/nmcli dev wifi connect $SSID password $PASSWORD
                fi
              '') cfg.networks);
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}

