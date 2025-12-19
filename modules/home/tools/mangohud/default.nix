{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.mangohud;
in {
  options.fmf.tools.mangohud = with types; {
    enable = mkBoolOpt false "Whether or not to enable mangohud.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [mangohud];};
}
