{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.plasma;

  default-attrs = mapAttrs (_key: mkDefault);
  nested-default-attrs = mapAttrs (_key: default-attrs);
in
{
  options.fmf.desktop.plasma = with types; {
    enable =
      mkBoolOpt false "Whether or not to use KDE Plasma as the desktop environment.";
    
    wayland = mkBoolOpt true "Whether or not to use Wayland.";
    
    tv-mode = mkBoolOpt false "Whether to optimize for TV/10-foot interface use.";
    
    wallpaper = mkOpt (nullOr (oneOf [ str package ]))
      null
      "The wallpaper to use. Set to null to use Plasma default.";
    
    scale = mkOpt (oneOf [ str int float ]) 1.0
      "Global scaling factor for the desktop (useful for 4K TVs).";
    
    dark-mode = mkBoolOpt false "Whether to use dark color scheme.";
    
    font-size = mkOpt int 10 "Base font size in points.";
    
    cursor-size = mkOpt int 24 "Cursor size in pixels.";
    
    icon-size = mkOpt int 48 "Desktop icon size in pixels.";
    
    panel-height = mkOpt int 44 "Panel height in pixels.";
    
    suspend = mkBoolOpt false "Whether or not to suspend the machine after inactivity.";
    
    autostart-apps = mkOpt (listOf str) [ ]
      "List of applications to autostart (desktop file names without .desktop).";
  };

  config = mkIf cfg.enable {
    fmf.system.xkb.enable = true;
    
    fmf.desktop.addons = {
      wallpapers = enabled;
    };

    # KDE Plasma 6 with Wayland support
    services.desktopManager.plasma6.enable = true;
    
    # Disable power-profiles-daemon if TLP is enabled (common conflict on laptops)
    services.power-profiles-daemon.enable = mkForce (!config.services.tlp.enable);
    
    # Configure display manager with SDDM
    fmf.desktop.display-manager.sddm = {
      enable = mkDefault true;
      wayland = mkDefault cfg.wayland;
    };
    
    services.displayManager = {
      defaultSession = mkDefault (if cfg.wayland then "plasma" else "plasmax11");
      autoLogin = mkIf cfg.suspend {
        enable = mkDefault false;  # Disable autoLogin if suspend is enabled for security
      };
    };

    # Enable X11 for compatibility
    services.xserver = {
      enable = true;
      libinput.enable = true;
    };

    # System packages for KDE Plasma
    environment.systemPackages = with pkgs; [
      kdePackages.plasma-browser-integration
      kdePackages.kde-gtk-config
      kdePackages.kdeconnect-kde
      kdePackages.plasma-nm
      kdePackages.bluedevil
      kdePackages.powerdevil
      kdePackages.plasma-pa
      kdePackages.discover
      kdePackages.sddm-kcm
      kdePackages.kscreen
      kdePackages.plasma-systemmonitor
      
      # Media and TV-friendly apps
      kdePackages.dragon  # Simple video player
      kdePackages.elisa   # Music player
      kdePackages.gwenview  # Image viewer
      
      # Utilities
      kdePackages.filelight  # Disk usage analyzer
      kdePackages.spectacle  # Screenshots
      kdePackages.ark  # Archive manager
    ] ++ optionals cfg.tv-mode [
      # Additional TV-optimized apps
      kodi  # Media center (already configured elsewhere, but ensure it's available)
    ];

    # Exclude unwanted default packages
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      # Remove unwanted applications for TV use
      konsole  # We might want a different terminal
      kate     # Text editor not needed for TV
    ];

    # Configure power management
    powerManagement = mkIf cfg.suspend {
      enable = true;
      cpuFreqGovernor = "powersave";
    };

    # Disable power management for TV mode (TVs should stay on)
    services.xserver.displayManager.gdm.autoSuspend = mkForce (!cfg.tv-mode);
    
    # KDE Connect for remote control from phone
    programs.kdeconnect.enable = true;

    # Home-manager configuration for Plasma
    # Note: Advanced Plasma configuration requires plasma-manager home-manager module
    # For now, users can configure Plasma manually through System Settings
    fmf.home.extraOptions = {
      # Create autostart entries
      home.file = mkMerge [
        (mkIf (cfg.autostart-apps != [ ]) (listToAttrs (map
          (app: {
            name = ".config/autostart/${app}.desktop";
            value = {
              text = ''
                [Desktop Entry]
                Type=Application
                Exec=${app}
                Hidden=false
                NoDisplay=false
                X-GNOME-Autostart-enabled=true
                Name=${app}
              '';
            };
          })
          cfg.autostart-apps)))
        
        # Set wallpaper path (if provided)
        (mkIf (cfg.wallpaper != null) {
          ".local/share/wallpapers/custom-wallpaper".source =
            if lib.isDerivation cfg.wallpaper
            then cfg.wallpaper
            else builtins.fetchurl cfg.wallpaper;
        })
      ];

      # Basic Plasma configuration via files
      xdg.configFile = mkMerge [
        # Global KDE settings (always set base config)
        {
          "kdeglobals".text = let
            sections = [
              (optionalString cfg.dark-mode ''
                [General]
                ColorScheme=BreezeDark
              '')
              ''
                [KDE]
                SingleClick=${if cfg.tv-mode then "true" else "false"}
              ''
              (optionalString cfg.tv-mode ''
                [Icons]
                Size=${toString cfg.icon-size}
              '')
            ];
          in lib.concatStringsSep "\n" (lib.filter (s: s != "") sections);
        }

        # Dark mode settings
        (mkIf cfg.dark-mode {
          "plasmarc".text = ''
            [Theme]
            name=breeze-dark
          '';
        })

        # TV mode settings
        (mkIf cfg.tv-mode {
          # Disable screen locker
          "kscreenlockerrc".text = ''
            [Daemon]
            Autolock=false
            LockOnResume=false
          '';
          
          # Disable power management
          "powermanagementprofilesrc".text = ''
            [AC]
            DimDisplay=false
            TurnOffDisplay=0
          '';
          
          # KWin compositor settings for TV / airmouse
          "kwinrc".text = ''
            [Compositing]
            Backend=${if cfg.wayland then "wayland" else "OpenGL"}
            GLCore=true
            
            [Windows]
            BorderlessMaximizedWindows=true
            Placement=Centered
            
            [Desktops]
            Number=4
            Rows=1
            
            [org.kde.kdecoration2]
            BorderSize=Tiny
            CloseDoubleClickOnMenuIcon=false
          '';
        })
      ];
    };
  };
}
