{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "fips_crypto_compliance";
  srgList = [ "SRG-OS-000478-GPOS-00223" ];
  stigConfig = {
    # Ensure kernel boots in FIPS mode
    boot.kernelParams = [ "fips=1" ];

    # Enforce FIPS mode in OpenSSL
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

    # Enforce FIPS for system-wide crypto
    security.apparmor.enable = true;
    security.apparmor.policies."system-wide-fips" = ''
      # Deny non-FIPS crypto
      deny /proc/sys/crypto/fips_enabled rw,
      deny /sys/module/fips_mode rw,
    '';

    # Ensure `libgcrypt` operates in FIPS mode
    environment.etc."gcrypt/fips_enabled".text = "1";
  };
}
