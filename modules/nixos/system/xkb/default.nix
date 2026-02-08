{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.xkb;
in
{
  options.fmf.system.xkb = with types; {
    enable = mkBoolOpt false "Whether or not to swap caps:escape.";
  };

  config = mkIf cfg.enable {
    console.useXkbConfig = true;

    services.xserver = {
      xkb.layout = "us";
      xkb.options = "caps:escape";
    };

    # console.keyMap = pkg.writeTextDir "swap_caps_esc.map" ''
    #   keymaps 0-127
    #   keycode 1 = Caps_Lock
    #   keycode 58 = escape
    # '';
  };
}
