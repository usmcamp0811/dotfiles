{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.webcord;
in {
  options.fmf.apps.webcord = with types; {
    enable = mkBoolOpt false "Whether or not to enable webcord.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [webcord];};
}
