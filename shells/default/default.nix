{ mkShell, inputs, system, pkgs, lib, ... }:
with lib;
with lib.campground;
let inherit (inputs.self.hooks.${system}.pre-commit-check) shellHook;
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
    # pkgs.campground.vault-scripts
    pkgs.vault-bin
    pkgs.zsh
    pkgs.oh-my-zsh
    pkgs.campground-nvim
    pkgs.campground.tmux
  ] ++ inputs.self.hooks.${system}.pre-commit-check.enabledPackages;

  pure = true;

  shellHook = ''
    ${shellHook}
    echo 🏕️ Welcome to the Campground
    export ZSH=$HOME/.oh-my-zsh
    export ZSH_THEME="fito"  # Replace with your desired theme
    export ZDOTDIR=$PWD/.zshrc  # Use a project-specific .zshrc
    exec zsh

    # Set up fzf for bash history search
    export FZF_DEFAULT_OPTS="--height 40% --reverse --border"

    # Bind Ctrl-R to fzf for history search
    # This replaces the default reverse-i-search with fzf
    # Load fzf keybindings and history search setup
    . ${pkgs.fzf}/share/fzf/key-bindings.bash
    # Include fzf completion (optional, helps with tab completion enhancements)
    . ${pkgs.fzf}/share/fzf/completion.bash
  '';
}
