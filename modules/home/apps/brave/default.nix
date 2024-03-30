{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.apps.brave;
  cacCertificates = pkgs.fetchurl {
    url =
      "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_WCF.zip";
    sha256 = "1inbf55mfqi0clsd8ybagfgz90n1h5knvs2rz33f7n6pjy7hcsnm";
  };
  cacCertificatesUnzipped = pkgs.runCommandNoCC "cac-certificates" {
    nativeBuildInputs = [ pkgs.unzip ];
  } ''
    mkdir $out
    unzip ${cacCertificates} -d $out
  '';

  cacCertificatesPaths =
    builtins.map (name: "${cacCertificatesUnzipped}/${name}")
    (builtins.filter (name: lib.hasSuffix ".p7b" name)
      (builtins.attrNames (builtins.readDir cacCertificatesUnzipped)));
  installCACertsScript = pkgs.writeScript "installCACerts.sh" ''
    #!/run/current-system/sw/bin/bash
    set -x
    set -e
    ls -lah ${pkgs.p11-kit}/lib
    echo "break"
    ls -lah ${pkgs.opensc}/lib/opensc-pkcs11.so
    ${pkgs.nssTools}/bin/modutil -dbdir sql:$HOME/.pki/nssdb/ -add "CAC Module" -libfile ${pkgs.opensc}/lib/opensc-pkcs11.so -force
    for certFile in ${builtins.concatStringsSep " " cacCertificatesPaths}
    do
      echo "Loading Cert into Brave: $certfile"
      ${pkgs.nssTools}/bin/certutil -d sql:${
        users.users.${cfg.name}.home
      }/.pki/nssdb -A -t TC -n "$certFile" -i "$certFile"
    done
  '';
in {
  options.campground.apps.brave = with types; {
    enable = mkBoolOpt false "Whether or not to enable Brave.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {

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
    # systemd.services.installCACerts = {
    #   description = "Install CAC certificates into Chromium based Browsers";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     RemainAfterExit = "yes";
    #     ExecStart = "${installCACertsScript}";
    #   };
    # };

  };
  # TODO: Add this shell script to set searx as default search
  # #!/bin/bash
  # 
  # # Define the search engine JSON entry with favicon_url
  # search_engine='{
  #   "default": false,
  #   "name": "Searx",
  #   "keyword": "searx",
  #   "search_url": "https://searx.aicampground.com/search?q={searchTerms}",
  #   "suggestions_url": "",
  #   "favicon_url": "https://searx.aicampground.com/static/themes/simple/img/favicon.svg"
  # }'
  # 
  # # Escape special characters for sed
  # escaped_search_engine=$(echo "$search_engine" | sed 's/[\/&]/\\&/g')
  # 
  # # Path to the Preferences file
  # preferences_file="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"
  # 
  # # Add the new search engine entry to Preferences
  # sed -i "/\"search_engines\": \[/a $escaped_search_engine," "$preferences_file"
  # 
  # echo "New search engine 'Searx' with favicon added to Preferences."

}

