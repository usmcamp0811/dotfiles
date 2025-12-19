{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "mfa_root_restrictions_usbguard";
  srgList = [
    "SRG-OS-000105-GPOS-00052"
    "SRG-OS-000106-GPOS-00053"
    "SRG-OS-000107-GPOS-00054"
    "SRG-OS-000108-GPOS-00055"
    "SRG-OS-000109-GPOS-00056"
    "SRG-OS-000114-GPOS-00059"
  ];
  cciList = [ "CCI-000765" "CCI-000766" "CCI-004045" ];
  stigConfig = {
    # Install a package enforcing multifactor authentication
    environment.systemPackages = [ pkgs.opencryptoki ];

    # Disable direct root login via SSH
    # TODO: Mkforce this some how
    services.openssh.permitRootLogin = mkForce "no";

    # Lock root user to prevent direct login
    users.mutableUsers = false;

    # Enable USBGuard to restrict unauthorized USB devices
    services.usbguard.enable = true;
  };
}
