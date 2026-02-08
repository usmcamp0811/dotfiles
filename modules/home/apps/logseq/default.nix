{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.logseq;
in {
  options.fmf.apps.logseq = {enable = mkEnableOption "logseq";};

  config = mkIf cfg.enable {home.packages = with pkgs; [logseq];};
}
