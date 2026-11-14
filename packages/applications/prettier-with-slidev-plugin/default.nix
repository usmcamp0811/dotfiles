{
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  slidevUpstream = pkgs.fetchFromGitHub {
    owner = "slidevjs";
    repo = "prettier-plugin";
    rev = "v1.0.5";
    hash = "sha256-AIlOwylRuZ6/I4whoc/dJdGRQoldWVzTucABsnCEREo=";
  };

  # Upstream ships a `lockfileVersion: 6.0` pnpm-lock.yaml, which pnpm 11 (the only non-EOL pnpm in nixpkgs)
  # rejects (ERR_PNPM_LOCKFILE_BREAKING_CHANGE; the Nix hook's --force turns that into "lockfile is broken:
  # it is empty"). The lockfile next to this file is the same project resolved by pnpm 11
  # (`pnpm install --lockfile-only --force`): dependency versions are therefore newer than upstream's pins.
  slidevSrc = pkgs.runCommand "prettier-plugin-slidev-src" {} ''
    cp -r ${slidevUpstream} $out
    chmod -R u+w $out
    cp ${./pnpm-lock.yaml} $out/pnpm-lock.yaml
  '';

  slidevPlugin = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "prettier-plugin-slidev";
    version = "1.0.5";
    src = slidevSrc;

    nativeBuildInputs = [pkgs.nodejs pkgs.pnpm pkgs.pnpmConfigHook pkgs.makeWrapper];

    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      hash = "sha256-B4GyOx3X5OuFOxDT9LmzF9dKdI1yVxTR6J41rLVEVLU=";
      fetcherVersion = 3;
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

    nativeBuildInputs = [pkgs.makeWrapper];

    buildCommand = ''
      mkdir -p $out/bin
      makeWrapper ${pkgs.prettier}/bin/prettier $out/bin/prettier \
        --add-flags "--plugin=${slidevPlugin}/lib/node_modules/prettier-plugin-slidev/index.js"
    '';
  };
in
  prettier-with-slidev
