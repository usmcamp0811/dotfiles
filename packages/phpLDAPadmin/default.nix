{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "phpLDAPadmin";
  version = "1.2.6.6";

  phpLDAPadmin = pkgs.stdenv.mkDerivation {
    name = "${pname}-${version}";
    src = pkgs.fetchurl {
      url = "https://github.com/leenooks/phpLDAPadmin/archive/refs/tags/${version}.tar.gz";
      sha256 = "sha256-eowCphHmCqZxPRz4Y9+sljfiPD9NQB6l5H2+KyLUiVo="; 
    };

    buildInputs = [ pkgs.php ];

    installPhase = ''
      mkdir -p $out/var/www
      cp -r . $out/var/www/${pname}
    '';


  };
  new-meta = with lib; {
    description = "A web-based LDAP administration tool";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in

override-meta new-meta phpLDAPadmin
