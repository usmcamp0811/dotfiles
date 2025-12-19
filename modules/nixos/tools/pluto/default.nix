{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.pluto;
in {
  options.fmf.tools.pluto = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Pluto.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [fmf.pluto];
  };
}
