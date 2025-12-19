{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.emoji-picker;
  inherit (pkgs.fmf) emoji-picker;
in {
  options.fmf.tools.emoji-picker = with types; {
    enable = mkBoolOpt false "Whether or not to enable emoji-picker.";
  };
  config = mkIf cfg.enable {home.packages = with pkgs; [emoji-picker];};
}
