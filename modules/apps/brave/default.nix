{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.brave;
  cacCertificates = pkgs.fetchurl {
    url = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_DoD.zip";
    sha256 = "09w9z6vs8r394wq2xk4gwaii9l04zb5h1q1qixbr9m45vnfs2i1v";
  };

  installCACertsScript = pkgs.writeShellScriptBin "installCACerts" ''
    set -x
    set -e
    HOME_DIR=${config.users.users.${config.campground.user.name}.home}
    DOD_CERT_DIR=$HOME_DIR/dodcerts
    NSS_DB_DIR=$HOME_DIR/.pki/nssdb
    mkdir -p $NSS_DB_DIR
    rm -rf $DOD_CERT_DIR
    ${pkgs.unzip}/bin/unzip -o ${cacCertificates} -d $DOD_CERT_DIR

    cd $DOD_CERT_DIR/certificates_pkcs7_v5_14_wcf
#    ${pkgs.nssTools}/bin/modutil -dbdir sql:$NSS_DB_DIR -add "CAC Module" -libfile ${pkgs.opensc}/lib/pkcs11/opensc-pkcs11.so -force
    for n in $(ls $DOD_CERT_DIR/certificates_pkcs7_v5_14_wcf/*.p7b); do
      echo $n
      ${pkgs.nssTools}/bin/certutil -d sql:$NSS_DB_DIR -A -t TC -n "$n" -i "$n"
    done
    rm -rf $DOD_CERT_DIR
  '';
in
{
  options.campground.apps.brave = with types; {
    enable = mkBoolOpt false "Whether or not to enable Brave.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nssTools
      brave
      installCACertsScript
    ];

    systemd.services.installCACerts = {
      description = "Install CAC certificates into Chromium based Browsers";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${installCACertsScript}/bin/installCACerts";
        User = config.campground.user.name;
      };
    };

    campground.services.cac.enable = mkIf cfg.cac true;
  };
}

