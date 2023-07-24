{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.firefox;
  cacCertificates = pkgs.fetchurl {
    url = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_WCF.zip";
    sha256 = "0myfy951v9mq0f3cf7zmw8mymkcszsmsxdlmiq1j0wk12w6l4qr0";
  };
  cacCertificatesUnzipped = pkgs.runCommandNoCC "cac-certificates" {} ''
    mkdir $out
    unzip ${cacCertificates} -d $out
  '';

  cacCertificatesPaths = builtins.trace (builtins.attrNames (builtins.readDir cacCertificatesUnzipped)) (builtins.map (name: "${cacCertificatesUnzipped}/${name}") (builtins.filter (name: lib.hasSuffix ".p7b" name) (builtins.attrNames (builtins.readDir cacCertificatesUnzipped))));
  firefoxPolicies = pkgs.writeText "policies.json" (builtins.toJSON {
    policies = {
      Certificates = {
        Install = cacCertificatesPaths;
      };
    };
  });
in
{
  options.campground.apps.firefox = with types; {
    enable = mkBoolOpt false "Whether or not to enable Firefox.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      firefox
    ];

    # TODO: Add things to exploade cac certs and install them into firefox here
    # TODO: See if we can automatically enable services.cac if we say cac enable here
    campground.services.cac.enable = mkIf cfg.cac true;
  };

}

