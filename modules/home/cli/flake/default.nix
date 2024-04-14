{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.cli.flake;
in
{
  options.campground.cli.flake = with types; {
    enable = mkBoolOpt false "Whether or not to enable flake.";
  };

  config =
    mkIf cfg.enable { home.packages = with pkgs; [ snowfallorg.flake ]; };
}
