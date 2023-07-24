{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.firefox;
  cacCertificates = pkgs.fetchurl {
    url = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_WCF.zip";
    sha256 = "1inbf55mfqi0clsd8ybagfgz90n1h5knvs2rz33f7n6pjy7hcsnm";
  };
  cacCertificatesUnzipped = pkgs.runCommandNoCC "cac-certificates" {
    nativeBuildInputs = [ pkgs.unzip ];
  } ''
    mkdir $out
    unzip ${cacCertificates} -d $out
  '';

  cacCertificatesPaths = builtins.map (name: "${cacCertificatesUnzipped}/${name}") (builtins.filter (name: lib.hasSuffix ".p7b" name) (builtins.attrNames (builtins.readDir cacCertificatesUnzipped)));
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
      (firefox.overrideAttrs (oldAttrs: {
        postInstall = oldAttrs.postInstall or "" + ''
          mkdir -p $out/lib/firefox/distribution
          cp ${firefoxPolicies} $out/lib/firefox/distribution/policies.json
        '';
      }))
      nssTools
    ];

    systemd.services.installCACerts = {
      description = "Install CAC certificates into Firefox";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        for certDB in ''$(find /home/*/.mozilla* -name "cert9.db")
        do
          cert_dir=''$(dirname ''${certDB});
          for certFile in ${builtins.concatStringsSep " " cacCertificatesPaths}
          do
            echo "Installing ''${certFile}' in ''${cert_dir}"
            ${pkgs.nssTools}/bin/certutil -A -n "''${certFile}" -t "TCu,Cuw,Tuw" -i "''${certFile}" -d sql:"''${cert_dir}"
          done
        done
      '';
    };


    # TODO: Add things to exploade cac certs and install them into firefox here
    # TODO: See if we can automatically enable services.cac if we say cac enable here
    campground.services.cac.enable = mkIf cfg.cac true;
  };
}

