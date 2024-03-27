{ lib, config, pkgs, inputs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli.srob-example;
in {
  options.campground.cli.srob-example = { enable = mkEnableOption "Enable srobs Neovim config"; };

  config = mkIf cfg.enable {
    home.activation.linkNVimConfig = inputs.home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
      rm -rf $HOME/.config/nvim
      cp -r ${pkgs.srob-nvim}/src $HOME/.config/nvim
    '';
  };
}
