{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "fips_crypto_compliance";
  srgList = [ "SRG-OS-000478-GPOS-00223" ];
  stigConfig = {
    boot.kernelParams = [ "fips=1" ];
    security.pki.enable = true;
    security.pki.certificates = [ "/etc/ssl/certs/ca-certificates.crt" ];
    environment.etc."openssl.cnf".text = ''
      [ openssl_conf ]
      alg_section = evp_properties

      [ evp_properties ]
      fips_mode = yes
    '';
  };
}
