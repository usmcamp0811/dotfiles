{
  config,
  lib,
  options,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.display-manager.regreet;
  greetdSwayConfig = pkgs.writeText "greetd-sway-config" ''
    exec dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK
    exec systemctl --user import-environment

    ${cfg.swayOutput}

    input "type:touchpad" {
      tap enabled
    }


    xwayland disable

    bindsym XF86MonBrightnessUp exec light -A 5
    bindsym XF86MonBrightnessDown exec light -U 5
    bindsym Print exec ${getExe pkgs.grim} /tmp/regreet.png
    bindsym Mod4+shift+e exec ${
      getExe' config.programs.sway.package "swaynag"
    } \
      -t warning \
      -m 'What do you want to do?' \
      -b 'Poweroff' 'systemctl poweroff' \
      -b 'Reboot' 'systemctl reboot'

    exec "${getExe pkgs.greetd.regreet} -l debug; ${
      getExe' config.programs.sway.package "swaymsg"
    } exit"
  '';
in {
  options.fmf.desktop.display-manager.regreet = with types; {
    enable = mkBoolOpt false "Whether or not to enable greetd.";
    swayOutput = mkOpt lines "" "Sway Outputs config.";
    font = mkOpt types.str "MonaspiceNe Nerd Font" "Default font name";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      config.fmf.desktop.addons.gtk.cursor.pkg
      config.fmf.desktop.addons.gtk.icon.pkg
      config.fmf.desktop.addons.gtk.theme.pkg
      pkgs.vulkan-validation-layers
    ];

    programs.regreet = {
      enable = true;

      settings = {
        # background = {
        #   path = pkgs.fmf.wallpapers.flatppuccin_macchiato;
        #   fit = "Cover";
        # };

        GTK = {
          application_prefer_dark_theme = true;
          cursor_theme_name = mkDefault "${config.fmf.desktop.addons.gtk.cursor.name}";
          font_name = mkDefault "${config.fmf.system.fonts.default} * 12";
          icon_theme_name = mkDefault "${config.fmf.desktop.addons.gtk.icon.name}";
          theme_name = mkDefault "${config.fmf.desktop.addons.gtk.theme.name}";
        };
      };
    };

    services.greetd.settings.default_session = {
      command = "env GTK_USE_PORTAL=0 ${getExe pkgs.sway} --config ${greetdSwayConfig}";
    };

    security.pam.services.greetd = {
      enableGnomeKeyring = true;
      gnupg.enable = true;
    };
  };
}
