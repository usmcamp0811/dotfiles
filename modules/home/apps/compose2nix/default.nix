{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.compose2nix;
in {
  options.fmf.apps.compose2nix = with types; {
    enable = mkBoolOpt false "Whether or not to enable Compose2Nix.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [compose2nix];};
}
