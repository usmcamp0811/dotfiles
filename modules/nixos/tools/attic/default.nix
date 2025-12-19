{ config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.attic;
in
{
  options.fmf.tools.attic = { enable = mkEnableOption "Attic"; };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ attic-client ]; };
}
