{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.vmware;
in {
  options.fmf.apps.vmware = with types; {
    enable = mkBoolOpt false "Whether or not to enable Firefox.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [vmware-workstation];
  };
}
