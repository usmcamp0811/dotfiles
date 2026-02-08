{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.nix-output-monitor;
in {
  options.fmf.tools.nix-output-monitor = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common Nix Output Monitor.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [output-monitor];
  };
}
