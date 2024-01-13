{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.desktop.qtile;

  # TODO: Look at renaming.. figure this oculd be used to put gui apps that make qtile config pretty and what not
  defaultExtensions = with pkgs; [
    networkmanagerapplet
    arc-theme

  ];

  default-attrs = mapAttrs (key: mkDefault);
  nested-default-attrs = mapAttrs (key: default-attrs);
in
{
  options.campground.desktop.qtile = with types; {
    enable =
      mkBoolOpt false "Whether or not to use Qtile as the desktop environment.";
    wayland = mkBoolOpt false "Whether or not to use Wayland.";
    gdm = mkBoolOpt false "Whether or not to use GDM Display Manager.";
    lightdm = mkBoolOpt false "Whether or not to use LightDM Display Manager.";
    sddm = mkBoolOpt false "Whether o not to use SDDM.";
    suspend =
      mkBoolOpt false "Whether or not to suspend the machine after inactivity.";
  };


  config = mkIf cfg.enable {
    campground.system.xkb.enable = true;
    campground.desktop.addons = {
      wallpapers = enabled;
    };

    environment.systemPackages = with pkgs; [
      gtk4
      qtile
      rofi
      xclip
      xsel
      feh
      dunst
      autorandr
      arandr
      go-sct
      brightnessctl 
    ] ++ defaultExtensions;

    programs.hyprland.enable = true;

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

        if ! [ -d "$(dirname "$config_file")" ]; then
          mkdir -p "$(dirname "$config_file")"
        fi

        if ! [ -f "$config_file" ]; then
          echo "[User]
          Session=gnome
          SystemAccount=false
          Icon=$icon_file" > "$config_file"
        else
          icon_config=$(grep -E "^Icon=.*$" $config_file)

          if [[ "$icon_config" == "" ]]; then
            echo "Icon=$icon_file" >> $config_file
          else
            sed -E -i -e "s#^Icon=.*\$#Icon=$icon_file#" $config_file
          fi
        fi

      '';
    };


  };
}
