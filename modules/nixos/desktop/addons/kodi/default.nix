{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.kodi;

  kodiPkgs = pkgs.kodi-wayland.packages;

  huluLauncher = pkgs.writeShellApplication {
    name = "hulu-live";

    runtimeInputs = [
      pkgs.coreutils
    ];

    text = ''
      set -euo pipefail

      profile_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/hulu-live/brave"
      mkdir -p "$profile_dir"

      export NIXOS_OZONE_WL=1

      exec ${pkgs.brave}/bin/brave \
        --app=${lib.escapeShellArg cfg.hulu.url} \
        --user-data-dir="$profile_dir" \
        --start-fullscreen \
        --no-first-run \
        --no-default-browser-check \
        --disable-session-crashed-bubble \
        --disable-background-mode \
        "$@"
    '';
  };

  huluDesktopItem = pkgs.makeDesktopItem {
    name = "hulu-live";
    desktopName = "Hulu Live TV";
    comment = "Watch Hulu Live TV in Brave";
    exec = "${huluLauncher}/bin/hulu-live";
    icon = "brave-browser";
    terminal = false;

    categories = [
      "AudioVideo"
      "Video"
      "Network"
    ];
  };

  # Small local Kodi script add-on that launches the Brave Hulu application.
  huluKodiAddon =
    kodiPkgs.toKodiAddon
    (
      pkgs.runCommand "kodi-hulu-live-addon-1.0.0" {
        propagatedBuildInputs = [];

        passthru = {
          namespace = "plugin.program.hulu-live";
          extraRuntimeDependencies = [];
        };
      } ''
        addon_dir="$out${kodiPkgs.addonDir}/plugin.program.hulu-live"

        mkdir -p "$addon_dir/resources"

        cat > "$addon_dir/addon.xml" <<'EOF'
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <addon
          id="plugin.program.hulu-live"
          name="Hulu Live TV"
          version="1.0.0"
          provider-name="FMF"
        >
          <requires>
            <import addon="xbmc.python" version="3.0.0"/>
          </requires>

          <extension
            point="xbmc.python.script"
            library="default.py"
          />

          <extension point="xbmc.addon.metadata">
            <summary lang="en_GB">
              Open Hulu Live TV in Brave
            </summary>

            <description lang="en_GB">
              Launches Hulu Live TV in a dedicated fullscreen Brave window.
            </description>

            <platform>linux</platform>
            <license>MIT</license>

            <assets>
              <icon>resources/icon.png</icon>
            </assets>
          </extension>
        </addon>
        EOF

        cat > "$addon_dir/default.py" <<'EOF'
        import subprocess

        subprocess.Popen(
            ["${huluLauncher}/bin/hulu-live"],
            start_new_session=True,
        )
        EOF

        cp \
          ${pkgs.brave}/share/icons/hicolor/256x256/apps/brave-browser.png \
          "$addon_dir/resources/icon.png"
      ''
    );

  configuredAddons = addons:
    optionals cfg.jellyfin.enable [
      addons.jellyfin
    ]
    ++ optionals cfg.keymap.enable [
      addons.keymap
    ]
    ++ optionals cfg.hulu.enable [
      huluKodiAddon
    ]
    ++ map (
      addonName:
        if builtins.hasAttr addonName addons
        then builtins.getAttr addonName addons
        else
          throw ''
            fmf.desktop.addons.kodi.extraAddons contains the unknown
            Kodi add-on "${addonName}".
          ''
    )
    cfg.extraAddons;

  # This wrapped Kodi package contains the configured add-ons.
  kodiPackage = pkgs.kodi-wayland.withPackages configuredAddons;
in {
  options.fmf.desktop.addons.kodi = with types; {
    enable =
      mkBoolOpt false
      "Whether to enable Kodi with native Wayland support.";

    jellyfin.enable =
      mkBoolOpt true
      "Whether to include the Jellyfin add-on for Kodi.";

    keymap.enable = mkBoolOpt true ''
      Whether to include Kodi's Keymap Editor add-on.

      This is useful for configuring buttons on keyboards,
      air mice, remotes, and other input devices.
    '';

    hulu = {
      enable = mkBoolOpt true ''
        Whether to include the Hulu Live TV launcher.

        Hulu opens in a dedicated fullscreen Brave window and
        uses a separate persistent browser profile.
      '';

      url = mkOpt str "https://www.hulu.com/live-tv" ''
        URL opened by the Hulu Live TV launcher.
      '';
    };

    extraAddons = mkOpt (listOf str) [] ''
      Additional Kodi add-on attribute names from
      pkgs.kodi-wayland.packages.

      Examples:

        "youtube"
        "sponsorblock"
        "netflix"
        "pvr-hdhomerun"
        "pvr-iptvsimple"
        "vfs-sftp"
        "vfs-rar"
        "upnext"
        "trakt"
    '';

    autoStart = mkBoolOpt false ''
      Whether to auto-start Kodi in fullscreen standalone mode.
      Useful for dedicated HTPC and TV setups.
    '';

    user = mkOpt (nullOr str) null ''
      User to add to the video, render, audio, and input groups.
      Typically this is the user that runs Kodi.
    '';

    hardwareAcceleration = mkBoolOpt true ''
      Whether to enable VA-API hardware video decoding support.
    '';
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        kodiPackage
      ]
      ++ optionals cfg.hulu.enable [
        pkgs.brave
        huluLauncher
        huluDesktopItem
      ];

    users.users = mkIf (cfg.user != null) {
      ${cfg.user}.extraGroups = [
        "video"
        "render"
        "audio"
        "input"
      ];
    };

    hardware.graphics = mkIf cfg.hardwareAcceleration {
      enable = true;

      extraPackages = with pkgs; [
        intel-media-driver
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
    };

    systemd.user.services.kodi = mkIf cfg.autoStart {
      description = "Kodi Media Center";

      after = [
        "graphical-session.target"
      ];

      partOf = [
        "graphical-session.target"
      ];

      wantedBy = [
        "graphical-session.target"
      ];

      serviceConfig = {
        ExecStart = "${kodiPackage}/bin/kodi --fullscreen --standalone";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
