{ pkgs
, lib
, ...
}:
with lib;
with lib.campground; let
  slidevPlugin = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "prettier-plugin-slidev";
    version = "1.0.5";
    src = pkgs.fetchFromGitHub {
      owner = "slidevjs";
      repo = "prettier-plugin";
      rev = "v${finalAttrs.version}";
      hash = "sha256-AIlOwylRuZ6/I4whoc/dJdGRQoldWVzTucABsnCEREo=";
    };

    nativeBuildInputs = [ pkgs.nodejs pkgs.pnpm_9.configHook pkgs.makeWrapper ];

    pnpmDeps = pkgs.pnpm_9.fetchDeps {
      inherit (finalAttrs) pname version src;
      hash = "sha256-EHISiqPo2hevf9ear0I7oAQs3rzagnd6M2zPrHwn0ig=";
    };

    buildPhase = ''
      pnpm build
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/prettier-plugin-slidev

      cp package.json $out/lib/node_modules/prettier-plugin-slidev/
      cp -r dist $out/lib/node_modules/prettier-plugin-slidev/
      cp -r node_modules $out/lib/node_modules/prettier-plugin-slidev/

      # Use an ES module wrapper
      echo "export { default } from './dist/index.js'" > $out/lib/node_modules/prettier-plugin-slidev/index.js

      runHook postInstall
    '';

    meta = {
      description = "Prettier plugin for Slidev";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  });

  prettier-with-slidev = pkgs.stdenv.mkDerivation {
    pname = "prettier-with-slidev";
    version = "3";

    nativeBuildInputs = [ pkgs.makeWrapper ];

    buildCommand = ''
      mkdir -p $out/bin
      makeWrapper ${pkgs.nodePackages.prettier}/bin/prettier $out/bin/prettier \
        --add-flags "--plugin=${slidevPlugin}/lib/node_modules/prettier-plugin-slidev/index.js"
    '';
  };
in
prettier-with-slidev
