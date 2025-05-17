{ pkgs
, lib
, inputs
, ...
}:
pkgs.stdenv.mkDerivation rec {
  pname = "@bufbuild";
  version = "1.4.0"; # or latest

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@bufbuild/protobuf/-/protobuf-${version}.tgz";
    sha512 = "sha512-urGGNsMG8YIyuhsjLFkx41CkAILFnUz9vHaUWvzOnzeoS2DykhSkUEpqTbf9cxG0Vzjmk2rl5ttmLwE0rbQyow==";
  };

  installPhase = ''
    mkdir -p $out/lib/node_modules/@bufbuild/protobuf
    tar --strip-components=1 -xzf $src -C $out/lib/node_modules/@bufbuild/protobuf
  '';

  meta = with lib; {
    description = "Protobuf runtime for JavaScript/TypeScript";
    homepage = "https://github.com/bufbuild/protobuf-javascript";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
