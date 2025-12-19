{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.minecraft;
in {
  options.fmf.apps.minecraft = with types; {
    enable = mkBoolOpt false "Whether or not to enable minecraft.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [minecraft];};
}
