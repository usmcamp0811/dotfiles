{ lib
, pkgs
, config
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.mpv;
in
{
  options.fmf.apps.mpv = { enable = mkEnableOption "mpv"; };

  config = mkIf cfg.enable {
    # fmf.cli.aliases = {
    #   mpv =
    #     "${pkgs.devour}/bin/devour ${pkgs.mpv}/bin/mpv --script=$HOME/.config/mpv/scripts/mpv-cheatsheet.js -ao=pipewire";
    # };

    programs.mpv = { enable = true; };
  };
}
