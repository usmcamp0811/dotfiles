{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.prismlauncher;
in {
  options.fmf.apps.prismlauncher = with types; {
    enable = mkBoolOpt false "Whether or not to enable prismlauncher.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [prismlauncher];};
}
