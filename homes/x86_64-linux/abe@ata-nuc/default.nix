{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = "abe";
    };

    cli = {
      zsh = enabled;
      home-manager = enabled;
    };
  };
  home.stateVersion = "23.05";
}
