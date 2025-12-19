{ lib
, pkgs
, config
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.cli-apps.neovim;
in
{
  options.fmf.cli-apps.neovim = { enable = mkEnableOption "Neovim"; };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      less
      campground-nvim
    ];
  };
}
