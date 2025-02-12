{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
mkStigModule {
  inherit config;
  name = "fips_password_security";
  srgList = [
    "SRG-OS-000478-GPOS-00223"
    "SRG-OS-000396-GPOS-00176"
    "SRG-OS-000480-GPOS-00225"
    "SRG-OS-000480-GPOS-00226"
    "SRG-OS-000480-GPOS-00227"
    "SRG-OS-000480-GPOS-00229"
    "SRG-OS-000480-GPOS-00230"
  ];
  cciList = [ "CCI-002450" "CCI-000366" ];
  stigConfig = {
    # Enable FIPS mode
    boot.kernelParams = [ "fips=1" ];

    # Enforce password dictionary check
    environment.etc."/security/pwquality.conf".text = ''
      dictcheck=1
    '';

    # Enforce password complexity rules
    security.pam.services.passwd.text = ''
      password requisite ${pkgs.libpwquality.lib}/lib/security/pam_pwquality.so
    '';

    security.pam.services.chpasswd.text = ''
      password requisite ${pkgs.libpwquality.lib}/lib/security/pam_pwquality.so
    '';

    security.pam.services.sudo.text = ''
      password requisite ${pkgs.libpwquality.lib}/lib/security/pam_pwquality.so
    '';

    # Enforce a four-second delay between failed login attempts
    environment.etc."login.defs".text = ''
      FAIL_DELAY 4
    '';

    # Disable unattended/automatic console login
    services.xserver.displayManager.autoLogin.user = null;

    # Enable AppArmor
    security.apparmor.enable = true;
  };
}
