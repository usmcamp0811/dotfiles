{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.barrier;
in {
  options.campground.apps.barrier = {enable = mkEnableOption "barrier";};

  config = mkIf cfg.enable {
    home.packages = with pkgs; [barrier];
    # home.file = {
    #   ".config/barrier/barrier.conf".source = ./barrier.conf;
    # };
  };
}
