{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "ssh_memory_protection";
  srgList = [
    "SRG-OS-000423-GPOS-00187"
    "SRG-OS-000112-GPOS-00057"
    "SRG-OS-000113-GPOS-00058"
    "SRG-OS-000424-GPOS-00188"
    "SRG-OS-000425-GPOS-00189"
    "SRG-OS-000426-GPOS-00190"
    "SRG-OS-000433-GPOS-00192"
  ];
  cciList =
    [ "CCI-002418" "CCI-001941" "CCI-002421" "CCI-002420" "CCI-002422" ];
  stigConfig = {
    # Enable SSHD for Secure Remote Access
    services.sshd.enable = true;

    # Memory Protection Settings (NX Bit & ASLR)
    boot.kernelParams = [
      "noexec=on" # Enforce non-executable stack
      "randomize_va_space=2" # Enable full ASLR (Address Space Layout Randomization)
    ];
  };
}
