{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "security_hardening";
  srgList = [
    "SRG-OS-000480-GPOS-00230"
    "SRG-OS-000368-GPOS-00154"
    "SRG-OS-000118-GPOS-00060"
    "SRG-OS-000120-GPOS-00061"
    "SRG-OS-000125-GPOS-00065"
    "SRG-OS-000375-GPOS-00160"
  ];
  cciList =
    [ "CCI-000366" "CCI-001764" "CCI-003627" "CCI-000803" "CCI-000877" ];
  stigConfig = {
    # Enable AppArmor
    security.apparmor.enable = true;

    # Disable inactive accounts after 35 days
    environment.etc."/default/useradd".text = pkgs.lib.mkForce ''
      INACTIVE=35
    '';

    # Ensure SHA-512 hashing is used for passwords
    security.pam.services.passwd.text =
      pkgs.lib.mkBefore "password required pam_unix.so sha512";

    # Enforce strong authentication for SSH
    services.openssh.settings.UsePAM = "yes";

    # Enforce multifactor authentication for remote privileged access
    security.pam.services.sshd.text =
      pkgs.lib.mkBefore "auth required pam_tally2.so deny=5 unlock_time=900";
    security.pam.services.sshd.text = pkgs.lib.mkAfter ''
      auth required pam_faillock.so preauth silent audit deny=5 unlock_time=900
      auth required pam_faillock.so authfail audit deny=5 unlock_time=900
    '';

    # Enforce secure SSH authentication with hardware tokens (CAC/PIV)
    security.pam.services.sshd.text =
      pkgs.lib.mkAfter "auth required pam_pkcs11.so";
  };
}
