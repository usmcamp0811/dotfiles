{ lib, ... }:
with lib.namespace-change-me; {
  namespace-change-me = {
    user = {
      enable = true;
      name = "example";
      fullName = "Matt Camp";
      email = "matt@ainamespace-change-me.com";
    };

    cli = { misc = enabled; };
    tools = { git = enabled; };
  };

  home.stateVersion = "23.05";
}
