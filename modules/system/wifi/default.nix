{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let cfg = config.campground.system.wifi;
in
{
  options.campground.system.wiki = with types; {
    enable = mkBoolOpt false "Whether or not to enable Wifi.";
    wifiNetworks = mkOption {
      type = attrsOf (submodule {
        options = {
          ssid = mkOption {
            type = str;
            description = "The SSID of the WiFi network.";
          };
          password = mkOption {
            type = str;
            description = "The password for the WiFi network.";
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
    networking.wireless.enable = true;
    networking.wireless.networks = lib.mapAttrs (name: network: {
      psk = network.password;
    }) (lib.filterAttrs (_: network: network.enable) cfg.wifiNetworks);
  };
}
