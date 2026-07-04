{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.kodi;

  configuredAddons = kodiPkgs:
    (lib.optionals cfg.jellyfin.enable [
      kodiPkgs.jellyfin
    ])
    ++ (lib.optionals cfg.jellycon.enable [
      kodiPkgs.jellycon
    ])
    ++ (lib.optionals cfg.youtube.enable [
      kodiPkgs.youtube
    ])
    ++ (lib.optionals (cfg.youtube.enable && cfg.youtube.sponsorBlock) [
      kodiPkgs.sponsorblock
    ])
    ++ (lib.optionals cfg.netflix.enable [
      kodiPkgs.netflix
    ])
    ++ (lib.optionals cfg.keymap.enable [
      kodiPkgs.keymap
    ])
    ++ (lib.optionals cfg.bluetoothManager.enable [
      kodiPkgs."bluetooth-manager"
    ])
    ++ builtins.map (
      addonName:
        if builtins.hasAttr addonName kodiPkgs
        then builtins.getAttr addonName kodiPkgs
        else
          throw ''
            fmf.desktop.addons.kodi.extraAddons contains the unknown
            Kodi add-on "${addonName}".
          ''
    )
    cfg.extraAddons;

  # This is the Kodi executable that includes all selected add-ons.
  kodiPackage = pkgs.kodi-wayland.withPackages configuredAddons;
in {
  options.fmf.desktop.addons.kodi = with types; {
    enable =
      mkBoolOpt false "Whether to enable Kodi (Wayland) for a TV-connected computer.";

    jellyfin.enable =
      mkBoolOpt true "Whether to include Jellyfin for Kodi.";

    jellycon.enable = mkBoolOpt false ''
      Whether to include JellyCon.

      JellyCon behaves like a traditional streaming add-on instead of
      synchronizing the Jellyfin library into Kodi's local database.
    '';

    youtube = {
      enable = mkBoolOpt false "Whether to include the YouTube add-on.";

      sponsorBlock = mkBoolOpt true ''
        Whether to include SponsorBlock when the YouTube add-on is enabled.
      '';
    };

    netflix.enable =
      mkBoolOpt false "Whether to include the Netflix add-on.";

    keymap.enable = mkBoolOpt true ''
      Whether to include Kodi's Keymap Editor.

      This is useful for remapping buttons from keyboards, air mice,
      remotes, and other Kodi input devices.
    '';

    bluetoothManager.enable = mkBoolOpt false ''
      Whether to include the Bluetooth Manager add-on.
    '';

    extraAddons = mkOpt (listOf str) [] ''
      Additional Kodi add-on attribute names from kodi-wayland.packages.

      Examples include:
        "pvr-hdhomerun"
        "pvr-iptvsimple"
        "vfs-sftp"
        "vfs-rar"
        "trakt"
        "upnext"
        "steam-launcher"
        "invidious"
    '';

    autoStart = mkBoolOpt false ''
      Whether to auto-start Kodi in fullscreen kiosk mode.
      Useful for dedicated HTPC/TV setups.
    '';

    user = mkOpt (nullOr str) null ''
      User to add to video/render/audio/input groups for hardware access.
      Typically the user that will run Kodi.
    '';

    hardwareAcceleration = mkBoolOpt true ''
      Whether to enable VA-API hardware video decoding support.
    '';
  };

  config = mkIf cfg.enable {
    # Install the wrapped Kodi package, not Kodi and the add-ons separately.
    environment.systemPackages = [
      kodiPackage
    ];

    users.users = lib.mkIf (cfg.user != null) {
      ${cfg.user}.extraGroups = [
        "video"
        "render"
        "audio"
        "input"
      ];
    };

    hardware.graphics = lib.mkIf cfg.hardwareAcceleration {
      enable = true;

      extraPackages = with pkgs; [
        intel-media-driver
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };

    environment.sessionVariables = {
      XDG_SESSION_TYPE = "wayland";
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
    };

    systemd.user.services.kodi = lib.mkIf cfg.autoStart {
      description = "Kodi Media Center";
      after = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];

      serviceConfig = {
        # Launch the wrapped package so autostart sees the same add-ons.
        ExecStart = "${kodiPackage}/bin/kodi --fullscreen --standalone";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
