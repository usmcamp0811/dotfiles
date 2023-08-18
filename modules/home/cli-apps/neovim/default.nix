{ lib, config, pkgs, inputs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli-apps.neovim;
in
{
  options.campground.cli-apps.neovim = {
    enable = mkEnableOption "Neovim";
  };

  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        less
        inputs.campground-nvim.packages.x86_64-linux.default
      ];
    };
  };
}
