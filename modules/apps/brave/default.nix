{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.brave;
  cacCertificates = pkgs.fetchurl {
    url = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_WCF.zip";
    sha256 = "1inbf55mfqi0clsd8ybagfgz90n1h5knvs2rz33f7n6pjy7hcsnm";
  };

  installCACertsScript = pkgs.writeShellScriptBin "installCACerts" ''
    set -x
    set -e
    HOME_DIR=${config.users.users.${config.campground.user.name}.home}
    DOD_CERT_DIR=$HOME_DIR/dodcerts
    NSS_DB_DIR=$HOME_DIR/.pki/nssdb
    mkdir -p $NSS_DB_DIR
    ${pkgs.unzip}/bin/unzip ${cacCertificates} -d $DOD_CERT_DIR
    cd $DOD_CERT_DIR
    ls -lah ${pkgs.opensc}/lib/
    ${pkgs.nssTools}/bin/modutil -dbdir sql:$NSS_DB_DIR -add "CAC Module" -libfile ${pkgs.opensc}/lib/opensc-pkcs11.so -force
    for n in $(ls * | grep Certificates); do
      ${pkgs.nssTools}/bin/certutil -d sql:$NSS_DB_DIR -A -t TC -n "$n" -i "$n"
    done
    chown -R ${config.campground.user.name} $HOME_DIR
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

