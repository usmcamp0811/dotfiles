{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.kodi;
in {
  options.fmf.desktop.addons.kodi = with types; {
    enable =
      mkBoolOpt false "Whether to enable Kodi (Wayland) for a TV-connected computer.";

    jellyfin = {
      enable = mkBoolOpt true "Whether to include the Jellyfin addon for Kodi.";
    };

    autoStart = mkBoolOpt false ''
      Whether to auto-start Kodi in fullscreen kiosk mode.
      Useful for dedicated HTPC/TV setups.
    '';

    user = mkOpt (nullOr str) null ''
      User to add to video/render/audio groups for hardware access.
      Typically the user that will run Kodi.
    '';

    hardwareAcceleration = mkBoolOpt true ''
      Whether to enable VA-API hardware video decoding support.
    '';
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Kodi with native Wayland support
      kodi-wayland
    ] ++ lib.optionals cfg.jellyfin.enable [
      # Jellyfin addon for Kodi
      kodi-wayland.packages.jellyfin
    ];

    # Add the specified user to groups needed for hardware access
    users.users = lib.mkIf (cfg.user != null) {
      ${cfg.user} = {
        extraGroups = [
          "video"
          "render"
          "audio"
          "input"
        ];
      };
    };

    # Hardware video acceleration for smooth playback
    hardware.graphics = lib.mkIf cfg.hardwareAcceleration {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiIntel
        vaapiVdpau
        libvdpau-va-gl
      ];
    };

    # Wayland session environment variables for Kodi
    environment.sessionVariables = {
      XDG_SESSION_TYPE = "wayland";
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
    };

    # Auto-start Kodi in kiosk mode (fullscreen, no window decorations)
    systemd.user.services.kodi = lib.mkIf cfg.autoStart {
      description = "Kodi Media Center";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = ''
          ${pkgs.kodi-wayland}/bin/kodi --fullscreen --standalone
        '';
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
