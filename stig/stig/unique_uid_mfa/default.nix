{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
mkStigModule {
  inherit config;
  name = "unique_uid_mfa";
  srgList = [
    "SRG-OS-000104-GPOS-00051"
    "SRG-OS-000121-GPOS-00062"
    "SRG-OS-000105-GPOS-00052"
  ];
  cciList = [ "CCI-000764" "CCI-000804" ];
  stigConfig = {
    # Ensure unique UIDs for interactive users
    systemd.tmpfiles.rules = [ "f /etc/passwd 0644 root root -" ];

    # Require MFA for privileged network access (DoD CAC + PKI)
    security.pam.services.sudo.text = ''
      auth required pam_tally2.so deny=5 unlock_time=900
      auth required pam_pkcs11.so
    '';
    services.sssd.enable = true;
    # TODO: Need to make option to pass in the path to the ca
    # security.pki.certificateFiles = [ "/etc/sssd/pki/sssd_auth_ca_db.pem" ];
  };
}
