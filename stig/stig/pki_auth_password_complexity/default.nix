{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
mkStigModule {
  inherit config;
  name = "pki_auth_password_complexity";
  srgList = [
    "SRG-OS-000066-GPOS-00034"
    "SRG-OS-000403-GPOS-00182"
    "SRG-OS-000775-GPOS-00230"
    "SRG-OS-000067-GPOS-00035"
    "SRG-OS-000069-GPOS-00037"
    "SRG-OS-000070-GPOS-00038"
    "SRG-OS-000071-GPOS-00039"
    "SRG-OS-000072-GPOS-00040"
    "SRG-OS-000073-GPOS-00041"
    "SRG-OS-000074-GPOS-00042"
    "SRG-OS-000075-GPOS-00043"
    "SRG-OS-000076-GPOS-00044"
    "SRG-OS-000078-GPOS-00046"
    "SRG-OS-000104-GPOS-00051"
  ];
  cciList = [
    "CCI-000185"
    "CCI-002470"
    "CCI-004909"
    "CCI-000186"
    "CCI-004066"
    "CCI-004062"
    "CCI-000197"
  ];
  stigConfig = {
    # Enable SSSD and configure it to use the DOD root CA
    services.sssd.enable = true;
    environment.etc."sssd/pki/sssd_auth_ca_db.pem".source = let
      certzip = pkgs.fetchzip {
        url =
          "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_v5-6_dod.zip";
        sha256 = "sha256-iwwJRXCnONk/LFddQlwy8KX9e9kVXW/QWDnX5qZFZJc=";
      };
    in "${certzip}/DOD_PKE_CA_chain.pem";

    # Require passphrases for SSH keys
    systemd.tmpfiles.rules = [
      "z /root/.ssh/id_rsa 0600 root root -"
      "z /home/*/.ssh/id_rsa 0600 root root -"
    ];

    # Enforce password complexity rules
    environment.etc."/security/pwquality.conf".text = ''
      minlen=15
      ucredit=-1
      lcredit=-1
      dcredit=-1
      difok=8
    '';

    # Enforce password storage security
    environment.etc."login.defs".text = ''
      ENCRYPT_METHOD SHA512
      PASS_MIN_DAYS 1
      PASS_MAX_DAYS 60
    '';

    # Ensure Telnet is not installed
    environment.systemPackages = pkgs.lib.mkForce (builtins.filter (pkg:
      pkg != pkgs.inetutils && pkg != pkgs.busybox && pkg != pkgs.libtelnet)
      config.environment.systemPackages);
  };
}
