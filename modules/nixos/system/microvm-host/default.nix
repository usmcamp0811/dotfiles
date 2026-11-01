{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.microvm-host;
in {
  options.fmf.system.microvm-host = {
    enable =
      mkBoolOpt (config.microvm.vms or {} != {})
      "Whether to prepare this host to run MicroVMs. Defaults to on when microvm.vms is non-empty.";
  };

  config = mkIf cfg.enable {
    # microvm-tap-interfaces@<vm> opens /dev/net/tun. If tun isn't loaded at
    # boot the unit fails and every microvm@<vm> dies with "Dependency failed".
    boot.kernelModules = ["tun"];

    # boot.kernelModules is not enough on its own: on sledge the stage-2
    # systemd-modules-load run was skipped (/etc/modules-load.d did not exist
    # yet when its condition was checked), so tun was never loaded and
    # vm-niks3 failed after every reboot. Make the unit that needs the device
    # load it itself.
    systemd.services."microvm-tap-interfaces@".serviceConfig.ExecStartPre = [
      "${pkgs.kmod}/bin/modprobe tun"
    ];
  };
}
