{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.fmf.tools.ssh;
in {
  options.fmf.tools.ssh = { enable = mkEnableOption "SSH"; };

  config = mkIf cfg.enable {
    programs.ssh = {
      enableDefaultConfig = false;
      matchBlocks."*".extraOptions = { HostKeyAlgorithms = "+ssh-rsa"; };
    };
  };
}
