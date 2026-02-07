{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.cac;
in {
  options.fmf.services.cac = with types; {
    enable = mkBoolOpt false "Enable CAC Support;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [pcsclite opensc ccid];

    services.pcscd.enable = true;
  };
}
