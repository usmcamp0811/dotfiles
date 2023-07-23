{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.openssh;
  # TODO: Feel like if they update the cert this will break.. whats the best way to handle this?
  cacCertificates = pkgs.fetchurl {
    url = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_WCF.zip";
    sha256 = "0myfy951v9mq0f3cf7zmw8mymkcszsmsxdlmiq1j0wk12w6l4qr0";
  };
in
{
  options.campground.services.cac = with types; {
    enable = mkBoolOpt false "Enable CAC Support;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pcsclite
      opensc
      ccid
    ];

  };
}
