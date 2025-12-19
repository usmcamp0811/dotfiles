{ config
, lib
, ...
}:
with lib; let
  cfg = config.fmf.desktop.xkb;
in
{
  options.fmf.desktop.xkb = with lib.types; {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether or not to configure xkb.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.keyboard = {
      layout = "us";
      xkbOptions = "caps:escape";
    };
  };
}
