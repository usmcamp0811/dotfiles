{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.archetypes.headless;
in
{
  options.fmf.archetypes.headless = with types; {
    enable = mkEnableOption "desktop home enviornment";
  };

  config = mkIf cfg.enable {
    fmf = {
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
