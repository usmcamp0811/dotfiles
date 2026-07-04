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
    
    wallpaper = mkOpt (oneOf [ str package ])
      pkgs.fmf.wallpapers.nord-rainbow-dark-nix
      "The wallpaper to use.";
    
    scale = mkOpt (oneOf [ str int float ]) 1.0
      "Global scaling factor for the desktop (useful for 4K TVs).";
    
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
    
    services.displayManager = {
      sddm = {
        enable = true;
        wayland.enable = cfg.wayland;
        autoNumlock = true;
      };
      defaultSession = if cfg.wayland then "plasma" else "plasmax11";
      autoLogin = mkIf cfg.suspend {
        enable = false;  # Disable autoLogin if suspend is enabled for security
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
      libsForQt5.filelight  # Disk usage analyzer
      libsForQt5.spectacle  # Screenshots
      libsForQt5.ark  # Archive manager
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
    fmf.home.extraOptions = {
      # Plasma configuration via plasma-manager
      programs.plasma = {
        enable = true;
        
        # Workspace behavior for TV mode
        workspace = mkIf cfg.tv-mode {
          clickItemTo = "open";  # Single-click to open
          
          # Theme and appearance
          theme = "breeze-dark";
          colorScheme = "BreezeDark";
          
          # Cursor settings
          cursor = {
            theme = "breeze_cursors";
            size = cfg.cursor-size;
          };
        };

        # Hotkeys optimized for remote control
        hotkeys.commands = mkIf cfg.tv-mode {
          "launch-kodi" = {
            name = "Launch Kodi";
            key = "Meta+K";
            command = "kodi";
          };
          "launch-browser" = {
            name = "Launch Browser";  
            key = "Meta+B";
            command = if config.fmf.apps.firefox.enable then "firefox" else "plasma-browser";
          };
        };

        # Panels configuration
        panels = mkIf cfg.tv-mode [
          {
            location = "bottom";
            height = cfg.panel-height;
            hiding = "none";  # Always visible for TV
            floating = false;
            
            widgets = [
              {
                kickoff = {
                  icon = "nix-snowflake";
                  sortAlphabetically = true;
                };
              }
              "org.kde.plasma.icontasks"
              "org.kde.plasma.marginsseparator"
              {
                systemTray.items = {
                  shown = [
                    "org.kde.plasma.networkmanagement"
                    "org.kde.plasma.bluetooth"
                    "org.kde.plasma.volume"
                  ];
                  hidden = [
                    "org.kde.plasma.battery"
                  ];
                };
              }
              {
                digitalClock = {
                  time.format = "24h";
                  date = {
                    enable = true;
                    format = "longDate";
                    position = "besideTime";
                  };
                };
              }
            ];
          }
        ];

        # Shortcuts for TV-friendly navigation
        shortcuts = mkIf cfg.tv-mode {
          "kwin" = {
            "Show Desktop" = "Meta+D";
            "Switch to Desktop 1" = "Meta+1";
            "Switch to Desktop 2" = "Meta+2";
            "Switch to Desktop 3" = "Meta+3";
            "Switch to Desktop 4" = "Meta+4";
            "Walk Through Windows" = "Meta+Tab";
            "Walk Through Windows (Reverse)" = "Meta+Shift+Tab";
            "Toggle Present Windows (All desktops)" = "Meta+W";
            "Toggle Present Windows (Current desktop)" = "Meta+A";
          };
          "plasmashell" = {
            "activate task manager entry 1" = [ ];  # Disable default app shortcuts
            "activate task manager entry 2" = [ ];
            "activate task manager entry 3" = [ ];
            "activate task manager entry 4" = [ ];
            "activate task manager entry 5" = [ ];
            "activate task manager entry 6" = [ ];
            "activate task manager entry 7" = [ ];
            "activate task manager entry 8" = [ ];
            "activate task manager entry 9" = [ ];
            "activate task manager entry 10" = [ ];
          };
        };

        # Window rules for TV mode
        window-rules = mkIf cfg.tv-mode [
          {
            description = "Kodi Fullscreen";
            match = {
              window-class = {
                value = "kodi";
                type = "substring";
              };
            };
            apply = {
              fullscreen = {
                value = true;
                apply = "initially";
              };
              noborder = {
                value = true;
                apply = "force";
              };
            };
          }
        ];

        # Configure fonts for TV viewing
        fonts = mkIf cfg.tv-mode {
          general = {
            family = "Noto Sans";
            pointSize = cfg.font-size;
          };
          fixedWidth = {
            family = "FiraCode Nerd Font";
            pointSize = cfg.font-size;
          };
        };

        # Autostart applications
        configFile = mkMerge [
          (mkIf (cfg.autostart-apps != [ ]) {
            "autostart" = listToAttrs (map
              (app: {
                name = "${app}.desktop";
                value = {
                  source = "${pkgs.kdePackages.plasma-workspace}/share/applications/${app}.desktop";
                };
              })
              cfg.autostart-apps);
          })
          
          # TV-specific settings
          (mkIf cfg.tv-mode {
            # Disable screen saver and power management
            "kscreenlockerrc" = {
              "Daemon" = {
                "Autolock" = false;
                "LockOnResume" = false;
              };
            };
            
            "powermanagementprofilesrc" = {
              "AC" = {
                "DimDisplay" = false;
                "TurnOffDisplay" = 0;  # Never turn off display
              };
            };
            
            # Configure KWin for TV
            "kwinrc" = {
              "Compositing" = {
                "Backend" = if cfg.wayland then "wayland" else "OpenGL";
                "GLCore" = true;
                "GLPreferBufferSwap" = "a";
                "GLTextureFilter" = 2;  # Accurate filtering
                "HiddenPreviews" = 5;
                "OpenGLIsUnsafe" = false;
                "WindowsBlockCompositing" = false;  # Always use compositing
              };
              
              "Plugins" = {
                "blurEnabled" = true;
                "contrastEnabled" = true;
                "slideEnabled" = true;
                "zoomEnabled" = true;
              };
              
              "Windows" = {
                "BorderlessMaximizedWindows" = true;  # Maximize without borders
                "Placement" = "Centered";
                "RollOverDesktops" = true;
              };
              
              "Desktops" = {
                "Number" = 4;
                "Rows" = 1;
              };
            };
            
            # Configure display scaling
            "kdeglobals" = {
              "KScreen" = {
                "ScaleFactor" = cfg.scale;
              };
              
              # Large icons for TV
              "Icons" = {
                "Size" = cfg.icon-size;
              };
            };
          })
        ];
      };

      # Set wallpaper
      home.file.".local/share/wallpapers/custom-wallpaper".source =
        if lib.isDerivation cfg.wallpaper
        then cfg.wallpaper
        else pkgs.fetchurl { url = cfg.wallpaper; };
    };
  };
}
