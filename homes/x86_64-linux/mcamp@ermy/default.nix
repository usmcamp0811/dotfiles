{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib.campground; {
  campground = {
    user = {
      enable = true;
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
    };

    cli = {
      zsh = enabled;
      env = enabled;
      home-manager = enabled;
      ranger = enabled;
    };
    services = { openssh = enabled; };

    tools = {
      git = enabled;
      direnv = enabled;
      python = enabled;
      vault = enabled;
    };
  };

  home.stateVersion = "23.05";
}
