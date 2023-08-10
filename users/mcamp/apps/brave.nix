{ config, lib, pkgs, ... }:

with lib;

let
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

  installCACertsScript = pkgs.writeScript "installCACerts.sh" ''
    #!/run/current-system/sw/bin/bash
    set -x
    set -e
    ${pkgs.nssTools}/bin/modutil -dbdir sql:$HOME/.pki/nssdb/ -add "CAC Module" -libfile ${pkgs.opensc}/lib/opensc-pkcs11.so -force
    for certFile in ${builtins.concatStringsSep " " cacCertificatesPaths}
    do
      echo "Loading Cert into Brave: $certFile" # Fixed typo here: $certfile -> $certFile
      ${pkgs.nssTools}/bin/certutil -d sql:${config.home.homeDirectory}/.pki/nssdb -A -t TC -n "$certFile" -i "$certFile"
    done
  '';
in
{
  home.packages = with pkgs; [
    nssTools
    pkcs11helper
  ];

  programs.brave = {
    enable = true;
    package = pkgs.brave;
    extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
      { id = "iaddfgegjgjelgkanamleadckkpnjpjc"; } # Auto Quality for YouTube
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
      { id = "annfbnbieaamhaimclajlajpijgkdblo"; } # Dark Theme
    ];
  };
  home.activation.installCACerts = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${installCACertsScript}
  '';
}

