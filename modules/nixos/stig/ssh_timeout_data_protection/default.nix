{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "ssh_timeout_data_protection";
  srgList = [
    "SRG-OS-000163-GPOS-00072"
    "SRG-OS-000279-GPOS-00109"
    "SRG-OS-000395-GPOS-00175"
    "SRG-OS-000185-GPOS-00079"
  ];
  cciList = [ "CCI-001133" "CCI-002361" "CCI-002891" ];
  stigConfig = {
    # Enforce automatic termination of inactive SSH sessions
    services.openssh.extraConfig = ''
      ClientAliveInterval 600
      ClientAliveCountMax 1
    '';

    # Ensure data at rest protection
    fileSystems."/".options = [ "defaults" "noatime" "nodiratime" "discard" ];

    # Ensure swap is encrypted if used
    swapDevices = [{ device = "/dev/mapper/swap"; }];
    # TODO: Feel like this needs more attention
    # TODO: Update with actual devices
    boot.initrd.luks.devices = {
      swap = {
        device = "/dev/sdx"; # Replace with actual swap partition
        allowDiscards = true;
        keyFile = "/etc/keys/swap.key";
      };
    };
  };
}
