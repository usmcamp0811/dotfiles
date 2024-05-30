{ lib, config, ... }:
with lib.campground; {
  campground = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };

    cli = {
      zsh = enabled;
      home-manager = enabled;
    };
    tools = { git = enabled; };
  };
  home.stateVersion = "23.05";
}
