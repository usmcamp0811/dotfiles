{
  config,
  lib,
  options,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.display-manager.sddm;
  sddmHome = config.users.users.sddm.home;
in {
  options.fmf.desktop.display-manager.sddm = with types; {
    enable = mkBoolOpt false "Whether or not to enable sddm.";
    wayland = mkBoolOpt true "Whether or not to use Wayland.";
    theme = mkOpt str "astronaut" "The theme to use.";

    # SDDM-NixOS theme options
    # sddmTheme = {
    #   enable = mkBoolOpt false "Whether to use sddm-nixos themes.";
    #   name = mkOpt (enum [
    #     "astronaut"
    #     "black_hole"
    #     "japanese_aesthetic"
    #     "pixel_sakura_static"
    #     "purple_leaves"
    #     "cyberpunk"
    #     "post-apocalyptic_hacker"
    #     "hyprland_kath"
    #     "pixel_sakura"
    #     "jake_the_dog"
    #   ]) "cyberpunk" "The sddm-nixos theme to use.";
    # };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = ["d ${sddmHome}/.config 0711 sddm sddm"];

    # Import the sddm-nixos theme package if enabled
    environment.systemPackages = [
      pkgs.fmf.sddm-themes
      pkgs.sddm-astronaut
    ];

    services = {
      displayManager = {
        sddm = {
          enable = true;
          package = pkgs.kdePackages.sddm;
          wayland.enable = cfg.wayland;
          extraPackages = [
            pkgs.sddm-astronaut
            pkgs.kdePackages.qtbase
            pkgs.kdePackages.qtwayland
            pkgs.kdePackages.qtmultimedia
          ];
          theme = cfg.theme;
          settings = {
            Theme = {
              Current = "sddm-astronaut-theme";
            };
          };
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

          if ! [ -d "$(dername "$config_file")" ]; then
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

    system.activationScripts.postInstallSddm =
      stringAfter ["users"] # bash
      
      ''
        echo "Setting sddm permissions for user icon"
        ${
          getExe' pkgs.acl "setfacl"
        } -m u:sddm:x /home/${config.fmf.user.name}
        ${
          getExe' pkgs.acl "setfacl"
        } -m u:sddm:r /home/${config.fmf.user.name}/.face || true
      '';
  };
}
