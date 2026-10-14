{
  config,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.oom;
in {
  options.fmf.system.oom = with types; {
    enable =
      mkBoolOpt false
      "Whether to run userspace OOM killers (earlyoom + systemd-oomd) so memory exhaustion kills a runaway process instead of freezing the host.";

    earlyoom = {
      enable = mkBoolOpt true "Whether to run earlyoom.";

      freeMemThreshold =
        mkOpt (ints.between 1 100) 5
        "Percent of available memory below which earlyoom sends SIGTERM to the biggest process.";

      freeMemKillThreshold =
        mkOpt (ints.between 1 100) 2
        "Percent of available memory below which earlyoom sends SIGKILL.";

      freeSwapThreshold =
        mkOpt (ints.between 1 100) 10
        "Percent of free swap below which earlyoom sends SIGTERM (only when memory is also below its threshold).";

      freeSwapKillThreshold =
        mkOpt (ints.between 1 100) 5
        "Percent of free swap below which earlyoom sends SIGKILL.";

      avoid =
        mkOpt str "(^|/)(init|systemd|sshd|qemu-system.*|virtiofsd)$"
        "Regex of process names (comm) earlyoom must avoid killing, so the host stays reachable and VMs survive while build jobs are the victims.";
    };

    oomd.enable =
      mkBoolOpt true
      "Whether to enable systemd-oomd on the root, system and user slices (memory-pressure based, kills whole cgroups).";
  };

  config = mkIf cfg.enable {
    services.earlyoom = mkIf cfg.earlyoom.enable {
      enable = true;
      inherit
        (cfg.earlyoom)
        freeMemThreshold
        freeMemKillThreshold
        freeSwapThreshold
        freeSwapKillThreshold
        ;
      extraArgs = ["--avoid" cfg.earlyoom.avoid];
    };

    systemd.oomd = {
      enable = cfg.oomd.enable;
      enableRootSlice = cfg.oomd.enable;
      enableSystemSlice = cfg.oomd.enable;
      enableUserSlices = cfg.oomd.enable;
    };
  };
}
