{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "encryption_password_wireless";
  srgList = [
    "SRG-OS-000185-GPOS-00079"
    "SRG-OS-000404-GPOS-00183"
    "SRG-OS-000405-GPOS-00184"
    "SRG-OS-000780-GPOS-00240"
    "SRG-OS-000266-GPOS-00101"
    "SRG-OS-000299-GPOS-00117"
  ];
  cciList =
    [ "CCI-001199" "CCI-002475" "CCI-002476" "CCI-004910" "CCI-004066" ];
  stigConfig = {
    # Ensure all partitions except boot are encrypted
    boot.initrd.luks.devices = {
      root = {
        device = "/dev/sda1"; # Replace with actual root partition
        preLVM = true;
        allowDiscards = true;
      };
    };

    # Ensure password complexity requires at least one special character
    environment.etc."/security/pwquality.conf".text = ''
      ocredit=-1
    '';

    # Enforce wireless encryption settings (WPA2/Enterprise)
    # TODO: Update with real networks
    networking.wireless = {
      enable = true;
      userControlled.enable =
        false; # Prevent users from modifying Wi-Fi settings
      networks = {
        "secured-network" = {
          pskRaw =
            "WPA2-PSK-EXAMPLE"; # Replace with actual key or use wpa_supplicant
        };
      };
    };

    # Ensure WPA2/Enterprise encryption is used
    services.wpa_supplicant = {
      enable = true;
      configFile = "/etc/wpa_supplicant.conf";
    };

    # WPA Supplicant configuration enforcing WPA2 with EAP-TLS
    # TODO: Update with real things
    environment.etc."wpa_supplicant.conf".text = ''
      ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
      update_config=1
      network={
        ssid="secured-network"
        key_mgmt=WPA-EAP
        eap=TLS
        identity="user@example.com"
        ca_cert="/etc/ssl/certs/ca-cert.pem"
        client_cert="/etc/ssl/certs/client-cert.pem"
        private_key="/etc/ssl/private/client-key.pem"
      }
    '';
  };
}
