{ lib, config, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli.neovim;
in
{
  options.campground.cli.neovim = { enable = mkEnableOption "Neovim"; };

  config = mkIf cfg.enable {
    campground.cli.aliases = {
      vim = "${pkgs.campground-nvim}/bin/nvim $1";
      diff = "${pkgs.campground-nvim}/bin/nvim -d $1";
    };
    home = { packages = with pkgs; [ less campground-nvim ]; };
  };
}
