{ pkgs
, lib
, inputs
, ...
}:
pkgs.stdenv.mkDerivation rec {
  pname = "buffer-builder";
  version = "0.2.0"; # latest as of now

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/buffer-builder/-/buffer-builder-${version}.tgz";
    sha512 = "sha512-7VPMEPuYznPSoR21NE1zvd2Xna6c/CloiZCfcMXR1Jny6PjX0N4Nsa38zcBFo/FMK+BlA+FLKbJCQ0i2yxp+Xg==";
  };

  installPhase = ''
    mkdir -p $out/lib/node_modules/buffer-builder
    tar --strip-components=1 -xzf $src -C $out/lib/node_modules/buffer-builder
  '';

  meta = with lib; {
    description = "Node.js module for building buffers incrementally";
    homepage = "https://github.com/dodo/node-buffer-builder";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
