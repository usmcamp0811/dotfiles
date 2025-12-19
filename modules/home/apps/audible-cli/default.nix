{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.audible-cli;
in
{
  options.fmf.apps.audible-cli = { enable = mkEnableOption "audible-cli"; };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      audible-cli
      ffmpeg
      python3Packages.audible-activator
    ];
  };
}
