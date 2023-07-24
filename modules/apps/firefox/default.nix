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
  installCACertsScript = pkgs.writeScript "installCACerts.sh" ''
    #!/usr/bin/env bash

    function usage {
      echo "Error: no certificate filename or name supplied."
      echo "Usage: $ ./installcerts.sh <certname>.pem <Cert-DB-Name>"
      exit 1
    }

    certificate_file="$1"
    certificate_name="$2"

    if [ -z "$certificate_file" ] || [ -z "$certificate_name" ]
      then
        usage
    fi

    for certDB in $(find  ~/.mozilla* -name "cert9.db")
    do
      cert_dir=$(dirname ${certDB});
      echo "Mozilla Firefox certificate" "install '${certificate_name}' in ${cert_dir}"
      certutil -A -n "${certificate_name}" -t "TCu,Cuw,Tuw" -i ${certificate_file} -d sql:"${cert_dir}"
    done
  '';
in
{
  options.campground.apps.firefox = with types; {
    enable = mkBoolOpt false "Whether or not to enable Firefox.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nssTools
      firefox
    ];

    # TODO: Add things to exploade cac certs and install them into firefox here
  systemd.services.installCACerts = {
    description = "Install CAC certificates into Firefox";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${installCACertsScript} <certname>.pem <Cert-DB-Name>";
    };
  };
    campground.services.cac.enable = mkIf cfg.cac true;
  };
}

# TODO: Read this and do something with it
# https://github.com/NixOS/nixpkgs/issues/171978
# Firefox needs to be convinced to use p11-kit-proxy by running a command like this:
#
# modutil -add p11-kit-proxy -libfile ${p11-kit}/lib/p11-kit-proxy.so -dbdir ~/.mozilla/firefox/*.default
# I was also able to accomplish the same by making use of extraPolciies when overriding the firefox package:
#
#         extraPolicies = {
#           SecurityDevices.p11-kit-proxy = "${pkgs.p11-kit}/lib/p11-kit-proxy.so";
#         };
