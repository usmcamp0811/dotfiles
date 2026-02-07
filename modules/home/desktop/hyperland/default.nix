{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let
  # inherit (inputs) hyprland;
  cfg = config.fmf.desktop.hyprland;
in
{
  options.fmf.desktop.hyprland = with types; {
    enable = mkBoolOpt false "Whether or not to turn on hyperland config.";
    startup = mkOpt (listOf str) [ ] "List of commands to run when you login";
    appendConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra configuration lines to add to bottom of `~/.config/hypr/hyprland.conf`.
      '';
    };
    prependConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra configuration lines to add to top of `~/.config/hypr/hyprland.conf`.
      '';
    };
  };

  imports = [ ./apps.nix ./binds.nix ./variables.nix ./windowrules.nix ];

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig =
        # bash
        ''
          ${cfg.prependConfig}
          env = XDG_DATA_DIRS,'${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}':$XDG_DATA_DIRS
          env = HYPRLAND_TRACE,1
          # monitor=eDP-1, 2560x1600@165.04Hz, 0x0,2.0
          ${cfg.appendConfig}
        '';
      package = pkgs.hyprland;

      settings = {

        exec = [
          ''
            ${
              getExe pkgs.libnotify
            } --icon ~/.face -u normal "Hello $(whoami)"''
        ] ++ cfg.startup;
      };

      systemd = { enable = true; };
      xwayland.enable = true;
    };
  };
}
