{ lib, config, ... }:

with lib;
with lib.campground;

let
  inherit (lib) mapAttrs' nameValuePair;

  # Function to enforce WPA2/WPA3 on all defined SSIDs
  forceSecureWiFi = networks:
    mapAttrs'
      (ssid: attrs:
        nameValuePair ssid (attrs // { authProtocols = [ "WPA2" "WPA3" ]; }))
      networks;

in
mkStigModule {
  inherit config;
  name = "wireless_encryption";
  srgList = [ "SRG-OS-000299-GPOS-00117" ];
  stigConfig = {
    # TODO: We need to do at least an assertion to that says we must use these.. but I get an
    # infinite recurision right now.. and will need to fix
    # networking.wireless = {
    #   enable = true;
    #   interfaces = [ "wlan0" "wlan1" ];
    #
    #   # Override all defined networks to force WPA2/WPA3
    #   networks = mkOverride 50 (forceSecureWiFi (config.networking.wireless.networks or {}));
    # };
  };
}
