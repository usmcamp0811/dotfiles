{ pkgs
, lib
, inputs
, ...
}:
let
  nodeEnv = import ./node-env.nix {
    inherit (pkgs) lib stdenv nodejs python2 libtool runCommand writeTextFile writeShellScript;
    inherit pkgs;
  };
in
nodeEnv.buildNodePackage rec {
  pname = "sass-embedded";
  version = "1.88.0";
  name = "${pname}-${version}";
  packageName = "sass-embedded"; # Required by buildNodePackage

  src = pkgs.fetchFromGitHub {
    owner = "sass";
    repo = "embedded-host-node";
    rev = "ba6e09f4b0ef4c571e978d56644be1976701af39";
    hash = "sha256-a583SWAc5Ivz/UuUC9Laui9DFunZqzQh9Gh2UdS7hPw=";
  };

  buildInputs = [
    pkgs.nodejs
    pkgs.typescript
    pkgs.gts
  ];

  postInstall = ''
    mkdir -p dist/lib
    tsc -p tsconfig.build.json
    cp lib/index.mjs dist/lib/index.mjs
    cp -r lib/src/vendor/sass dist/lib/src/vendor/sass
    cp dist/lib/src/vendor/sass/index.d.ts dist/lib/src/vendor/sass/index.m.d.ts
    cp lib/index.js dist/lib/index.js || true
  '';
}
