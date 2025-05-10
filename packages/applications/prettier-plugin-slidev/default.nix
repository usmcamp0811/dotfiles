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

    installPhase = ''
      runHook preInstall
      mkdir -p $out/node_modules/prettier-plugin-slidev
      cp -r ./* $out/node_modules/prettier-plugin-slidev
      runHook postInstall
    '';

    meta = {
      description = "Prettier plugin for Slidev";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  });
  prettier-with-slidev = pkgs.symlinkJoin {
    name = "prettier-with-slidev";
    paths = [ pkgs.nodePackages.prettier ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/prettier \
        --add-flags "--plugin-search-dir=${slidevPlugin}" \
        --add-flags "--plugin=prettier-plugin-slidev"
    '';
  };
in
prettier-with-slidev
