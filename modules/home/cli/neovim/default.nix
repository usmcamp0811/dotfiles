{ lib, config, pkgs, inputs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli.neovim;
in
{
  options.campground.cli.neovim = {
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
