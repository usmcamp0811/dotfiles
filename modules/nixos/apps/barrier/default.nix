{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.barrier;
in {
  options.fmf.apps.barrier = with types; {
    enable = mkBoolOpt false "Whether or not to enable barrier.";
  };

  config =
    mkIf cfg.enable {environment.systemPackages = with pkgs; [barrier];};
}
