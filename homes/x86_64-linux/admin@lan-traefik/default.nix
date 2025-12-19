{ lib, ... }:
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = "admin";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
    };
    archetypes.headless = enabled;
  };

  home.stateVersion = "23.05";
}
