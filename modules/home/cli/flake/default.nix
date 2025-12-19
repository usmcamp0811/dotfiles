{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cli.flake;
in
{
  options.fmf.cli.flake = with types; {
    enable = mkBoolOpt false "Whether or not to enable flake.";
  };

  config =
    mkIf cfg.enable { home.packages = with pkgs; [ snowfallorg.flake ]; };
}
