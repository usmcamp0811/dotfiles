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
    pkgs.vault-bin
    pkgs.zsh
    pkgs.oh-my-zsh
    pkgs.fzf
  ] ++ inputs.self.hooks.${system}.pre-commit-check.enabledPackages;
  pure = true;

  shellHook = ''
    ${shellHook}
    echo 🏕️ Welcome to the Campground

    # Set ZSH configuration directory
    export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh

    # Set your desired oh-my-zsh theme
    export ZSH_THEME="fino"

    # Source oh-my-zsh
    . $ZSH/oh-my-zsh.sh

    # Source fzf keybindings and other settings
    export FZF_DEFAULT_OPTS="--height 40% --reverse --border"

    # Source fzf zsh keybindings and completion scripts
    . ${pkgs.fzf}/share/fzf/completion.zsh
    . ${pkgs.fzf}/share/fzf/key-bindings.zsh

    # Source zsh-autosuggestions if available
    . ${pkgs.fzf}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_STRATEGY=(history)

    # Finally, switch to zsh
    if [ -n "$ZSH_VERSION" ]; then
      echo "You are already in zsh"
    else
      zsh
    fi
  '';
}
