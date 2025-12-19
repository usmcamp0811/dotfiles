{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib;
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };

    cli = {
      zsh = enabled;
      home-manager = enabled;
      env = enabled;
    };
  };
  home.stateVersion = "23.05";
}
