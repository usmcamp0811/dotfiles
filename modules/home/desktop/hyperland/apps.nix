{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.desktop.hyprland;
  configure-gtk = pkgs.writeTextFile {
    name = "configure-gtk";
    destination = "/bin/configure-gtk";
    executable = true;
    text = let
      schema = pkgs.gsettings-desktop-schemas;
      datadir = "${schema}/share/gesettings/schemas/${schema.name}";
    in ''
      export XDG_DATA_DIRS=${datadir}:$XDG_DATA_DIRS
      gnome_schema=org.gnome.desktop.interface
      gesettings set $gnome_schema gtk-theme 'Adwaita'
    '';
  };
  dbus-hyprland-environment = pkgs.writeTextFile {
    name = "dbus-hyprland-environment";
    destination = "/bin/dbus-hyprland-environment";
    executable = true;

    text = ''
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=hyprland
      systemctl --user stop pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
      systemctl --user start pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    '';
  };
in {
  config = mkIf cfg.enable {
    # systemd.user.services.hypr_socket_watch = {
    #   Install.WantedBy = [ "hyprland-session.target" ];
    #
    #   Unit = {
    #     Description = "Hypr Socket Watch Service";
    #     PartOf = [ "graphical-session.target" ];
    #   };
    #
    #   Service = {
    #     Environment = "PATH=/run/wrappers/bin:${lib.makeBinPath hypr_socket_watch_dependencies}";
    #     ExecStart = "${getExe pkgs.campground.hypr_socket_watch}";
    #     Restart = "on-failure";
    #   };
    # };

    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          # ░█▀█░█▀█░█▀█░░░█▀▀░▀█▀░█▀█░█▀▄░▀█▀░█░█░█▀█
          # ░█▀█░█▀▀░█▀▀░░░▀▀█░░█░░█▀█░█▀▄░░█░░█░█░█▀▀
          # ░▀░▀░▀░░░▀░░░░░▀▀▀░░▀░░▀░▀░▀░▀░░▀░░▀▀▀░▀░░

          # Startup background apps
          "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1 &"
          # "${getExe pkgs.openrgb} --startminimized --profile default"
          # "${getExe pkgs._1password-gui} --silent"
          "command -v ${getExe pkgs.cliphist} && ${
            getExe' pkgs.wl-clipboard "wl-paste"
          } --type text --watch cliphist store" # Stores only text data
          "command -v ${getExe pkgs.cliphist} && ${
            getExe' pkgs.wl-clipboard "wl-paste"
          } --type image --watch cliphist store" # Stores only image data

          "${dbus-hyprland-environment}"
          "${configure-gtk}"
          # Startup apps that have rules for organizing them
          # "${getExe pkgs.firefox}"
          # "${getExe pkgs.steam}"
          # "${getExe pkgs.discord}"
          # "${getExe pkgs.thunderbird}"
          # "${getExe pkgs.virt-manager}"
        ];
      };
    };
  };
}
