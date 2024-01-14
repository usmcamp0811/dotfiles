{ config
, lib
, options
, pkgs
, inputs
, system
, ...
}:
with lib;
with lib.campground;
let
  inherit (inputs) hyprland;
  inherit (inputs) nixpkgs-wayland;


  cfg = config.campground.desktop.hyprland;
  programs = lib.makeBinPath [ config.programs.hyprland.package ];
in
{
  options.campground.desktop.hyprland = with types; {
    enable = mkBoolOpt false "Whether or not to enable Hyprland.";
    customConfigFiles = mkOpt attrs { } "Custom configuration files that can be used to override the default files.";
    customFiles = mkOpt attrs { } "Custom files that can be used to override the default files.";
    wallpaper = mkOpt (nullOr package) null "The wallpaper to display.";
  };

  config =
    mkIf cfg.enable
      {
        environment.sessionVariables = {
          CLUTTER_BACKEND = "wayland";
          GDK_BACKEND = "wayland,x11";
          HYPRLAND_LOG_WLR = "1";
          MOZ_ENABLE_WAYLAND = "1";
          XKB_DEFAULT_OPTIONS= "caps:escape";
          MOZ_USE_XINPUT2 = "1";
          QT_QPA_PLATFORM = "wayland;xcb";
          WLR_NO_HARDWARE_CURSORS = "1";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          SDL_VIDEODRIVER = "wayland";
          WLR_DRM_NO_ATOMIC = "1";
          WLR_RENDERER = "vulkan";
          XDG_CURRENT_DESKTOP = "Hyprland";
          XDG_SESSION_DESKTOP = "Hyprland";
          XDG_SESSION_TYPE = "wayland";
          _JAVA_AWT_WM_NONEREPARENTING = "1";
          __GL_GSYNC_ALLOWED = "0";
          __GL_VRR_ALLOWED = "0";
        };

        environment.systemPackages = with pkgs; [
          hyprpaper
          cliphist
          swayimg
          nixpkgs-wayland.packages.${system}.wdisplays
          wl-screenrec
          nixpkgs-wayland.packages.${system}.wl-clipboard
          wlr-randr
          # Not really wayland specific, but I don't want to make a new module for it
          brightnessctl
          glib # for gsettings
          gtk3.out # for gtk-launch
          playerctl
        ];
        campground.display-managers = {
          gdm.enable = true;
          regreet = {
            enable = false;
          };
        };
        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
          package = hyprland.packages.${system}.hyprland;
          portalPackage = hyprland.packages.${system}.xdg-desktop-portal-hyprland;
        };
      };
}
