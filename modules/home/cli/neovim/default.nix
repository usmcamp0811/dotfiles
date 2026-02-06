{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.cli.neovim;
in
{
  options.fmf.cli.neovim = { enable = mkEnableOption "Neovim"; };

  config = mkIf cfg.enable {
    fmf.cli.aliases = {
      vim = "${pkgs.campground-nvim}/bin/nvim";
      # nvim = "${pkgs.campground-nvim}/bin/nvim";
      diff = "${pkgs.campground-nvim}/bin/nvim -d $1 $2";
    };
    home.packages = with pkgs; [ less campground-nvim ];
  };
}
