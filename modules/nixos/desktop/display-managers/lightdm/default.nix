{
  config,
  lib,
  options,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.display-manager.lightdm;
in {
  options.fmf.desktop.display-manager.lightdm = with types; {
    enable = mkBoolOpt false "Whether or not to enable lightdm.";
    greeter = lib.mkOption {
      type = lib.types.attrs;
      description = "Configuration for the LightDM greeter, mirroring the LightDM module options.";
      default = {
        enable = true;
        package = pkgs.lightdm-gtk-greeter;
        name = "lightdm-gtk-greeter";
        # Add any additional options you might need here
      };
    };
  };

  config = mkIf cfg.enable {
    services.xserver = {
      enable = true;
      displayManager = {
        lightdm = {
          enable = cfg.enable;
          greeter = cfg.greeter;
        };
      };

      libinput.enable = true;
    };

    systemd.services.campground-user-icon = {
      before = ["display-manager.service"];
      wantedBy = ["display-manager.service"];

      script =
        # bash
        ''
          config_file=/var/lib/AccountsService/users/${config.fmf.user.name}
          icon_file=/run/current-system/sw/share/icons/user/${config.fmf.user.name}/${config.fmf.user.icon.fileName}

          if ! [ -d "$(dirname "$config_file")" ]; then
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
  };
}
