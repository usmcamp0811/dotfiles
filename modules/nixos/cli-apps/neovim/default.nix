{ lib
, pkgs
, config
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli-apps.neovim;
in
{
  options.campground.cli-apps.neovim = { enable = mkEnableOption "Neovim"; };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      less
      campground-nvim
    ];
  };
}
