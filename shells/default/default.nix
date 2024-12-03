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
    pkgs.campground.vault-scripts
    pkgs.vault-bin
    pkgs.zsh
    pkgs.oh-my-zsh
    pkgs.fzf
    pkgs.util-linux # Provides `ps` and other standard utilities
    pkgs.coreutils # General Unix utilities
  ] ++ inputs.self.hooks.${system}.pre-commit-check.enabledPackages;

  pure = true;

  # Set Zsh as the default shell for this nix-shell environment
  shellHook = ''
    ${shellHook}
    echo 🏕️ Welcome to the Campground

    # Set ZSH configuration directory
    export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh

    # Set your desired oh-my-zsh theme
    export ZSH_THEME="fino"

    # Source oh-my-zsh
    if [ -n "$ZSH_VERSION" ]; then
      echo "You are already in zsh"
    else
      echo "Starting zsh..."
      exec zsh
    fi

    # Only source fzf and zsh settings if we're in zsh
    if [ -n "$ZSH_VERSION" ]; then
      # Source fzf keybindings and completion
      export FZF_DEFAULT_OPTS="--height 40% --reverse --border"
      . ${pkgs.fzf}/share/fzf/completion.zsh
      . ${pkgs.fzf}/share/fzf/key-bindings.zsh

      # Source zsh-autosuggestions if available
      if [ -f ${pkgs.fzf}/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
        . ${pkgs.fzf}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        ZSH_AUTOSUGGEST_STRATEGY=(history)
      else
        echo "Warning: zsh-autosuggestions not found"
      fi
    fi
  '';
}
