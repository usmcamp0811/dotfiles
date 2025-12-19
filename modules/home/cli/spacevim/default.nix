{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.cli.spacevim;
in
{
  options.fmf.cli.spacevim = { enable = mkEnableOption "Neovim"; };

  config =
    mkIf cfg.enable { home = { packages = with pkgs; [ less spacevim ]; }; };
}
