{ pkgs, ... }:
let
  slidev-presentation = pkgs.npmlock2nix.${pkgs.system}.build {
    src = ./packages/misc/nix-slide-deck/nix-slide-deck;

    installPhase = ''
      pnpm run build
      mkdir -p $out
      cp -r dist/* $out/
    '';
  };
in
slidev-presentation
