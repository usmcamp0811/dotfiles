{ config
, lib
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.desktop.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      settings = {
        animations = {
          enabled = "yes";

          # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more
          bezier = [
            "easein, 0.47, 0, 0.745, 0.715"
            "myBezier, 0.05, 0.9, 0.1, 1.05"
            "overshot, 0.13, 0.99, 0.29, 1.1"
            "scurve, 0.98, 0.01, 0.02, 0.98"
          ];

          animation = [
            "border, 1, 10, default"
            "fade, 1, 10, default"
            "windows, 1, 5, overshot, popin 10%"
            "windowsOut, 1, 7, default, popin 10%"
            "workspaces, 1, 6, overshot, slide"
          ];
        };

        debug = { disable_logs = false; };

        decoration = {
          active_opacity = 0.95;
          fullscreen_opacity = 1.0;
          inactive_opacity = 0.9;
          rounding = 10;

          blur = {
            enabled = "yes";
            passes = 4;
            size = 5;
          };
        };

        dwindle = {
          # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
          force_split = 0;
          preserve_split = true; # you probably want this
          pseudotile =
            true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        };

        general = {
          allow_tearing = true;
          border_size = 2;
          "col.active_border" = "rgba(FF69B4FF)";
          "col.inactive_border" = "rgb(5e6798)";
          gaps_in = 5;
          gaps_out = 20;
          layout = "master";
          # no_cursor_warps = true;
        };

        xwayland = { force_zero_scaling = true; };

        cursor.no_hardware_cursors = 1;
        gestures = {
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
          workspace_swipe_invert = false;
        };

        input = {
          follow_mouse = 1;
          kb_layout = "us";
          numlock_by_default = true;
          kb_options = "caps:swapescape";

          touchpad = {
            natural_scroll = "no";
            disable_while_typing = true;
            tap-to-click = true;
          };

          sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
        };

        master = {
          # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
          # new_is_master = true;
          special_scale_factor = 0.8;
          mfact = 0.55;
          new_on_top = false;
          # no_gaps_when_only = false;
          orientation = "left";
          inherit_fullscreen = true;
          # always_center_master = true;
        };

        misc = {
          disable_hyprland_logo = true;
          key_press_enables_dpms = true;
          mouse_move_enables_dpms = true;
          vrr = 2;
        };

        "$mainMod" = "ALT";
        "$LHYPER" = "SUPER_LALT_LCTRL"; # TODO: fix
        "$RHYPER" = "SUPER_RALT_RCTRL"; # TODO: fix

        # default applications
        "$term" = "${getExe pkgs.kitty}";
        "$browser" = "${getExe pkgs.brave}";
        "$mail" = "${getExe pkgs.thunderbird}";
        "$editor" = "${getExe pkgs.neovim}";
        "$explorer" = "${getExe pkgs.xfce.thunar}";
        "$music" = "${getExe pkgs.spotify}";
        "$launcher" = "${getExe config.programs.rofi.package} -show drun -n";
        "$launcher_alt" = "${getExe config.programs.rofi.package} -show calc";
        "$launcher_shift" = "${getExe config.programs.rofi.package} -show run -n";
        "$launchpad" = "${
          getExe config.programs.rofi.package
        } -show drun -config '~/.config/rofi/appmenu/rofi.rasi'";
        "$looking-glass" = "${getExe pkgs.looking-glass-client}";
      };
    };
  };
}
