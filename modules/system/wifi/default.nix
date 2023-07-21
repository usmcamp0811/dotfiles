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
    unmanagedInterfaces = mkOption {
      type = listOf str;
      default = [];
      description = "List of interfaces that should be left unmanaged by NetworkManager.";
    };
  };
  config = mkIf cfg.enable {
    networking.networkmanager.unmanaged = cfg.unmanagedInterfaces;
    # networking.wireless.enable = true;
    # networking.wireless.environmentFile = cfg.environmentFile;
    networking.wireless.networks = lib.mapAttrs (name: network: {
      psk = "@${name}@";
    }) (lib.filterAttrs (_: network: network.enable) cfg.networks);
  };
}

