{ pkgs
, lib
, inputs
, ...
}:
let
in
pkgs.stdenv.mkDerivation rec {
  pname = "varint";
  version = "6.0.0"; # check for latest if needed

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/varint/-/varint-${version}.tgz";
    sha512 = "sha512-cXEIW6cfr15lFv563k4GuVuW/fiwjknytD37jIOLSdSWuOI6WnO/oKwmP2FQTU2l01LP8/M5TSAJpzUaGe3uWg==";
  };

  installPhase = ''
    mkdir -p $out/lib/node_modules/varint
    tar --strip-components=1 -xzf $src -C $out/lib/node_modules/varint
  '';

  meta = with lib; {
    description = "Use varint encoding (used by protobuf)";
    homepage = "https://github.com/chrisdickinson/varint";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
