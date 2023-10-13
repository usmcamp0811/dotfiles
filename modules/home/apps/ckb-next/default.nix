{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.ckb-next;
in
{
  options.campground.apps.ckb-next = {
    enable = mkEnableOption "ckb-next";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      ckb-next
    ];
    home.file = { 
      ".config/ckb-next/ckb-next.conf".source = ./ckb-next.conf;
    };
  };
}
