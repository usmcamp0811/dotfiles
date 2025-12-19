{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.node;
in {
  options.fmf.tools.node = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Node.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [nodejs yarn];
  };
}
