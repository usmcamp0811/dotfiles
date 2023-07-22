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
    # networking.networkmanager.unmanaged = cfg.unmanagedInterfaces;
    # networking.wireless.enable = true;
    # networking.wireless.environmentFile = cfg.environmentFile;
    # networking.wireless.networks = lib.mapAttrs (name: network: {
    #   psk = "@${name}@";
    # }) (lib.filterAttrs (_: network: network.enable) cfg.networks);

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
            #TODO: Should this be a template? Or can this be done in a simpler way?
            "wifi-passwords" = {
              text = ''
                #!/bin/sh
                SSID_SkyNet="SkyNet"
                PASSWORD_SkyNet={{ with secret "secret/campground/wifi" }}{{ .Data.SkyNet }}{{ end }}
                if ! nmcli con show | grep -q $SSID_SkyNet; then
                  nmcli con add con-name $SSID_SkyNet ifname wlan0 type wifi ssid $SSID_SkyNet
                fi
                nmcli connection modify $SSID_SkyNet 802-11-wireless-security.psk $PASSWORD_SkyNet

                SSID_SkyNet5="SkyNet5"
                PASSWORD_SkyNet5={{ with secret "secret/campground/wifi" }}{{ .Data.SkyNet5 }}{{ end }}
                if ! nmcli con show | grep -q $SSID_SkyNet5; then
                  nmcli con add con-name $SSID_SkyNet5 ifname wlan0 type wifi ssid $SSID_SkyNet5
                fi
                nmcli connection modify $SSID_SkyNet5 802-11-wireless-security.psk $PASSWORD_SkyNet5
              '';
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}

