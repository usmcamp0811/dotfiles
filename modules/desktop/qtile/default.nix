{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.desktop.qtile;

  # TODO: Look at renaming.. figure this oculd be used to put gui apps that make qtile config pretty and what not
  defaultExtensions = with pkgs; [
    networkmanagerapplet

  ];

  default-attrs = mapAttrs (key: mkDefault);
  nested-default-attrs = mapAttrs (key: default-attrs);
in
{
  options.campground.desktop.qtile = with types; {
    enable =
      mkBoolOpt false "Whether or not to use Gnome as the desktop environment.";
    # wayland = mkBoolOpt true "Whether or not to use Wayland.";
    # suspend =
    #   mkBoolOpt true "Whether or not to suspend the machine after inactivity.";
  };

  # TODO: Whats all this doing exactly?
  config = mkIf cfg.enable {
    campground.system.xkb.enable = true;
    campground.desktop.addons = {
      # gtk = enabled;
      wallpapers = enabled;
      # electron-support = enabled;
      # foot = enabled;
    };

    environment.systemPackages = with pkgs; [
    ] ++ defaultExtensions ++ cfg.extensions;

    # environment.gnome.excludePackages = with pkgs.gnome; [
    # ];


    systemd.services.campground-user-icon = {
      before = [ "display-manager.service" ];
      wantedBy = [ "display-manager.service" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
      };

      script = ''
        config_file=/var/lib/AccountsService/users/${config.campground.user.name}
        icon_file=/run/current-system/sw/share/campground-icons/user/${config.campground.user.name}/${config.campground.user.icon.fileName}

        if ! [ -d "$(dirname "$config_file")"]; then
          mkdir -p "$(dirname "$config_file")"
        fi

        if ! [ -f "$config_file" ]; then
          echo "[User]
          Session=gnome
          SystemAccount=false
          Icon=$icon_file" > "$config_file"
        else
          icon_config=$(sed -E -n -e "/Icon=.*/p" $config_file)

          if [[ "$icon_config" == "" ]]; then
            echo "Icon=$icon_file" >> $config_file
          else
            sed -E -i -e "s#^Icon=.*$#Icon=$icon_file#" $config_file
          fi
        fi
      '';
    };

    services.udev.packages = with pkgs; [];

    services.xserver = {
      enable = true;

      libinput.enable = true;
      # displayManager.lightdm.enable = true;
      # displayManager.gdm = {
      #   enable = true;
      #   wayland = cfg.wayland;
      #   autoSuspend = cfg.suspend;
      # };
      desktopManager.qtile.enable = true;
    };

    campground.home.extraOptions = {
      # TODO: Set desktop with feh here?
      # dconf.settings =
      #   let
      #     user = config.users.users.${config.campground.user.name};
      #     get-wallpaper = wallpaper:
      #       if lib.isDerivation wallpaper then
      #         builtins.toString wallpaper
      #       else
      #         wallpaper;
      #   in
      #   nested-default-attrs {
      #   };
    };

    # Open firewall for samba connections to work.
    # networking.firewall.extraCommands =
    #   "iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns";
  };
}
