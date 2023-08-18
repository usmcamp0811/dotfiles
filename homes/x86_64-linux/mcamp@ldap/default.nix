{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground;
{
  campground = {
    user = {
      enable = true;
      # name = config.snowfallorg.user.name;
      # TODO: I think the above fails because we dont add this user to the system as a local user elsewhere it would probbly work ¯\_(ツ)_/¯
      name = "mcamp";
    };

    cli-apps = {
      zsh = enabled;
      env = enabled;
      # neovim = enabled;
      home-manager = enabled;
    };
    #
    apps = {
      firefox = enabled;
      brave = enabled;
    };
    tools = {
      # git = enabled;
      direnv = enabled;
    };
  };

  home.stateVersion = "23.05";
}
