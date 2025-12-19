{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.hardware.bluetooth;
in {
  options.fmf.hardware.bluetooth = with types; {
    enable = mkBoolOpt false "Whether or not to enable bluetooth support";
  };

  config = mkIf cfg.enable {
    services.blueman.enable = true;
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;

    environment.systemPackages = with pkgs; [blueman];
  };
}
