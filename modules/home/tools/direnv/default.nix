{ options
, config
, lib
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.tools.direnv;
in
{
  options.campground.tools.direnv = with types; {
    enable = mkBoolOpt false "Whether or not to enable direnv.";
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv = enabled;
    };
  };
}
