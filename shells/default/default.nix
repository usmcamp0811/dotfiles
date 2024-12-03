{ mkShell, inputs, system, pkgs, lib, ... }:
with lib;
with lib.campground;
let
  # inherit (lib.campground) override-meta;
  inherit (inputs.self.hooks.${system}.pre-commit-check) shellHook;
in
mkShell {
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
    pkgs.vault
    pkgs.zsh
    pkgs.oh-my-zsh
    pkgs.fzf
  ] ++ inputs.self.hooks.${system}.pre-commit-check.enabledPackages;
  pure = true;
  shellHook = ''
    ${shellHook}
    echo 🏕️ Welcome to the Campground
    # Additional setup can go here
    export ZSH=$HOME/.oh-my-zsh
    export ZSH_THEME="agnoster"  # Replace with your desired theme
    export ZDOTDIR=$PWD/.zshrc  # Use a project-specific .zshrc

    # Initialize fzf keybindings for shell history
    export FZF_DEFAULT_OPTS="--height 40% --reverse --border"
    bindkey '^R' fzf-history-widget



    exec zsh

  '';
}
