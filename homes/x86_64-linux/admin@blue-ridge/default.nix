{ lib, ... }:
with lib.campground; {
  campground = {
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
