{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.ckb-next;
in {
  options.fmf.apps.ckb-next = {enable = mkEnableOption "ckb-next";};

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ckb-next];
    home.file = {".config/ckb-next/ckb-next.conf".source = ./ckb-next.conf;};
  };
}
