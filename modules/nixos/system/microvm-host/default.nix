{
  config,
  lib,
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
  };
}
