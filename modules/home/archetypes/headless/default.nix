{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.archetypes.headless;
in
{
  options.campground.archetypes.headless = with types; {
    enable = mkEnableOption "desktop home enviornment";
  };

  config = mkIf cfg.enable {
    campground = {
      cli = {
        zsh = enabled;
        bash = enabled;
        env = enabled;
        home-manager = enabled;
        k9s = enabled;
        broot = enabled;
        yazi = enabled;
        neovim = enabled;
      };
      services = {
        openssh = enabled;
        syncthing = enabled;
      };
      tools = {
        git = enabled;
        direnv = enabled;
        vault = enabled;
      };
    };
  };
}
