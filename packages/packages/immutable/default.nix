{ pkgs
, lib
, inputs
, ...
}:
let
in
pkgs.stdenv.mkDerivation rec {
  pname = "immutable";
  version = "4.3.5"; # check latest version on npm if needed

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/immutable/-/immutable-${version}.tgz";
    sha512 = "sha512-8eabxkth9gZatlwl5TBuJnCsoTADlL6ftEr7A4qgdaTsPyreilDSnUk57SO+jfKcNtxPa22U5KK6DSeAYhpBJw==";
  };

  installPhase = ''
    mkdir -p $out/lib/node_modules/${pname}
    tar --strip-components=1 -xzf $src -C $out/lib/node_modules/${pname}
  '';

  meta = with pkgs.lib; {
    description = "Immutable data collections for JavaScript";
    homepage = "https://immutable-js.github.io/immutable-js/";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
