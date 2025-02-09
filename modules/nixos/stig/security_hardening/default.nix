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
    "SRG-OS-000068-GPOS-00036"
    "SRG-OS-000376-GPOS-00161"
    "SRG-OS-000377-GPOS-00162"
    "SRG-OS-000705-GPOS-00150"
    "SRG-OS-000383-GPOS-00166"
    "SRG-OS-000384-GPOS-00167"
    "SRG-OS-000439-GPOS-00195"
    "SRG-OS-000480-GPOS-00228"
  ];
  cciList = [
    "CCI-000366"
    "CCI-001764"
    "CCI-003627"
    "CCI-000803"
    "CCI-000877"
    "CCI-004046"
    "CCI-000187"
    "CCI-001953"
    "CCI-001954"
    "CCI-004047"
    "CCI-002007"
    "CCI-004068"
    "CCI-002605"
  ];
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

    # Enable strong authentication via PAM PKCS#11
    security.pam.p11.enable = true;

    # Ensure cached authentication credentials expire after one day
    services.sssd.config = ''
      [pam]
      offline_credentials_expiration = 1
    '';

    # Enable local certificate revocation data in case of network unavailability
    environment.etc."pam_pkcs11/pam_pkcs11.conf".text = ''
      cert_policy = ca,signature,ocsp_on, crl_auto;
    '';

    # Enforce NixOS to run on a supported version
    system.activationScripts.checkNixOSVersion = {
      text = ''
        if [[ "$(nixos-version | awk '{print $1}')" < "23.11" ]]; then
          echo "Unsupported NixOS version. Upgrade required."
          exit 1
        fi
      '';
    };

    # Default permissions for new users (restrict file access)
    environment.etc."login.defs".text = ''
      DEFAULT_HOME yes
      SYS_UID_MIN  400
      SYS_UID_MAX  999
      UID_MIN      1000
      UID_MAX      29999
      SYS_GID_MIN  400
      SYS_GID_MAX  999
      GID_MIN      1000
      GID_MAX      29999
      TTYGROUP     tty
      TTYPERM      0620
      UMASK        077
    '';
  };
}
