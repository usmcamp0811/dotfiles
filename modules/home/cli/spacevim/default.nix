{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli.spacevim;
in
{
  options.campground.cli.spacevim = { enable = mkEnableOption "Neovim"; };

  config =
    mkIf cfg.enable { home = { packages = with pkgs; [ less spacevim ]; }; };
}
