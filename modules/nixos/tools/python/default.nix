{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.python;
in {
  options.fmf.tools.python = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Python.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [python];
  };
}
