{lib, ...}:
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = "example";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
    };

    cli = {misc = enabled;};
    tools = {git = enabled;};
  };

  home.stateVersion = "23.05";
}
