{ mkShell, pkgs, config, system, inputs, lib, ... }:
with lib;
with lib.campground;
let 
  inherit (lib.campground) override-meta;
  inherit (inputs.self.checks.${system}.pre-commit-check) shellHook;
in mkShell {
  buildInputs = [
    pkgs.deadnix
    pkgs.hydra-check
    pkgs.nix-diff
    pkgs.nix-index
    pkgs.nix-prefetch-git
    pkgs.nixpkgs-fmt
    pkgs.nixpkgs-hammering
    pkgs.nixpkgs-lint
    pkgs.snowfallorg.flake
    pkgs.statix
    pkgs.campground.vault-scripts
  ] ++ inputs.self.checks.${system}.pre-commit-check.enabledPackages;
  shellHook = ''
    echo 🏕️ Welcome to the Campground
    # Additional setup can go here

  '';
}
