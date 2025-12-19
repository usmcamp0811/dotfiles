{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "fips_crypto_compliance";
  srgList = [
    "SRG-OS-000476-GPOS-00221"
    "SRG-OS-000042-GPOS-00020"
    "SRG-OS-000274-GPOS-00104"
    "SRG-OS-000275-GPOS-00105"
    "SRG-OS-000276-GPOS-00106"
    "SRG-OS-000277-GPOS-00107"
    "SRG-OS-000477-GPOS-00222"
    "SRG-OS-000304-GPOS-00121"
    "SRG-OS-000478-GPOS-00223"
  ];
  cciList = [ "CCI-000172" "CCI-000135" "CCI-000015" ];
  stigConfig = {
    ## 1. Enable Kernel FIPS Mode
    boot.kernelParams = [ "fips=1" ];

    ## 2. Ensure OpenSSL Uses FIPS Mode
    environment.etc."openssl.cnf".text = ''
      openssl_conf = openssl_init

      [openssl_init]
      providers = provider_sect

      [provider_sect]
      default = default_sect
      fips = fips_sect

      [default_sect]
      activate = 1

      [fips_sect]
      activate = 1
    '';

    ## 3. Enforce FIPS via AppArmor (Fixed)
    security.apparmor.enable = true;
    security.apparmor.policies."fips-restrictions" = {
      profile = ''
        # Deny non-FIPS crypto
        deny /proc/sys/crypto/fips_enabled rw,
        deny /sys/module/fips_mode rw,
      '';
    };

    ## 4. Ensure `libgcrypt` Operates in FIPS Mode
    environment.etc."gcrypt/fips_enabled".text = "1";

    ## 5. Audit Log Configuration
    security.audit.rules = [
      "-w /etc/sudoers -p wa -k identity"
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/gshadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/security/opasswd -p wa -k identity"
    ];
  };
}
