{ lib, stdenv, fetchurl, pkgs, writeText}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "phpLDAPadmin";
  version = "1.2.6.6";

  desc
  phpLDAPadmin = stdenv.mkDerivation {
    name = "${pname}-${version}";
    src = pkgs.fetchurl {
      url = "https://github.com/leenooks/phpLDAPadmin/archive/refs/tags/${version}.tar.gz";
      sha256 = "1p10r7dv6f03f099wlrbcrbg6znbpia8z30is7dwxqghnyy2a5a8"; # Replace with the actual hash
    };

    buildInputs = [ pkgs.php ];

    installPhase = ''
      mkdir -p $out/var/www
      cp -r . $out/var/www/${pname}
    '';

    meta = {
      description = "A web-based LDAP administration tool";
      homepage = "https://github.com/leenooks/phpLDAPadmin";
      platforms = [ "x86_64-linux" ];
    };
  };
in

override-meta new-meta phpLDAPadmin
