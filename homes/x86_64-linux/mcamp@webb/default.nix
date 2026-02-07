{lib, ...}:
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
    };
    archetypes.headless = enabled;
    services.syncthing = enabled;
  };

  home.stateVersion = "23.05";
}
