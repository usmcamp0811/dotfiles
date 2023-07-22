{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let cfg = config.campground.system.wifi;
in
{
  options.campground.system.wifi = with types; {
    enable = mkBoolOpt false "Whether or not to enable Wifi.";
    environmentFile = mkOpt str "/tmp/detsys-vault/wifi-passwords" "Location of WIFI Passwords File.";
    networks = mkOption {
      type = attrsOf (submodule {
        options = {
          ssid = mkOption {
            type = str;
            description = "The SSID of the WiFi network.";
          };
          enable = mkOption {
            type = bool;
            default = false;
            description = "Whether to connect to this WiFi network.";
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
        vault.address = "https://vault.lan.aicampground.com";
        auto_auth = {
          method = [{
            type = "approle";
            config = {
              role_id_file_path = "/var/lib/vault/wifi/role-id";
              secret_id_file_path = "/var/lib/vault/wifi/secret-id";
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
                if ! ${pkgs.networkmanager}/bin/nmcli con show | grep -q ${name}; then
                  PASSWORD_${name}={{ with secret "secret/campground/wifi" }}{{ .Data.${name} }}{{ end }}
                  ${pkgs.networkmanager}/bin/nmcli dev wifi connect ${name} password $PASSWORD_${name}
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

