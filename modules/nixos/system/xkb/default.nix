{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.xkb;
in
{
  options.campground.system.xkb = with types; {
    enable = mkBoolOpt false "Whether or not to swap caps:escape.";
  };

  config = mkIf cfg.enable {
    console.useXkbConfig = true;

    services.xserver = {
      layout = "us";
      xkbOptions = "caps:escape";
    };

    # console.keyMap = pkg.writeTextDir "swap_caps_esc.map" ''
    #   keymaps 0-127
    #   keycode 1 = Caps_Lock
    #   keycode 58 = escape
    # '';
  };
}
