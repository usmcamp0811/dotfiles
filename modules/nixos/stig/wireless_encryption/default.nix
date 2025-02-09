{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

let
  ssidList = builtins.readFile "/etc/nixos/detect-ssids.sh";
  parsedSSIDs =
    builtins.fromJSON (builtins.toJSON (builtins.split "\n" ssidList));
  forceSecureWiFi = { interfaces }: {
    enable = true;
    inherit interfaces;
    networks = builtins.listToAttrs (map
      (ssid: {
        name = ssid;
        value = { authProtocols = [ "WPA2" "WPA3" ]; };
      })
      parsedSSIDs);
  };
in
mkStigModule {
  inherit config;
  name = "wireless_encryption";
  srgList = [ "SRG-OS-000299-GPOS-00117" ];
  stigConfig = {
    networking.wireless = forceSecureWiFi { interfaces = [ "wlan0" "wlan1" ]; };
  };
}
