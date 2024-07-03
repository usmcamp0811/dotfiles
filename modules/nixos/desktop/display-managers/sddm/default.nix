{ config, lib, options, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.desktop.display-manager.sddm;
  sddmHome = config.users.users.sddm.home;
in {
  options.campground.desktop.display-manager.sddm = with types; {
    enable = mkBoolOpt false "Whether or not to enable sddm.";
    wayland = mkBoolOpt true "Whether or not to use Wayland.";
    theme = mkOpt str "" "The theme to use.";
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${sddmHome}/.config 0711 sddm sddm" ];

    services = {
      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = cfg.wayland;
          theme = cfg.theme;
        };
      };

      libinput.enable = true;
    };

    systemd.services.campground-user-icon = {
      before = [ "display-manager.service" ];
      wantedBy = [ "display-manager.service" ];

      script =
        # bash
        ''
          config_file=/var/lib/AccountsService/users/${config.campground.user.name}
          icon_file=/run/current-system/sw/share/icons/user/${config.campground.user.name}/${config.campground.user.icon.fileName}

          if ! [ -d "$(dirname "$config_file")" ]; then
            mkdir -p "$(dirname "$config_file")"
          fi

          if ! [ -f "$config_file" ]; then
            echo "[User]
            Session=${cfg.defaultSession or "plasma"}
            SystemAccount=false
            Icon=$icon_file" > "$config_file"
          else
            icon_config=$(sed -E -n -e "/Icon=.*/p" $config_file)

            if [[ "$icon_config" == "" ]]; then
              echo "Icon=$icon_file" >> $config_file
            else
              sed -E -i -e 's#^Icon=.*$#Icon=$icon_file#' $config_file
            fi
          fi
        '';

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
      };
    };

    system.activationScripts.postInstallSddm = stringAfter [ "users" ] # bash
      ''
        echo "Setting sddm permissions for user icon"
        ${
          getExe' pkgs.acl "setfacl"
        } -m u:sddm:x /home/${config.campground.user.name}
        ${
          getExe' pkgs.acl "setfacl"
        } -m u:sddm:r /home/${config.campground.user.name}/.face || true
      '';
  };
}
