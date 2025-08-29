{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.campground.hardware.via;
in {
  options.campground.hardware.via = with types; {
    enable = mkEnableOption "Keychron Keyboards & Mice";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.via
    ];
    # VIA/Vial udev rules for your specific Keychron device
    services.udev.extraRules = ''
      # Your Keychron Link (3434:d030)
      KERNEL=="hidraw*", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="d030", MODE="0666", GROUP="plugdev", TAG+="uaccess"
      # General Keychron VIA-compatible devices
      KERNEL=="hidraw*", ATTRS{idVendor}=="3434", MODE="0666", GROUP="plugdev", TAG+="uaccess"
      # Ensure WebHID can access the device
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"
    '';
    # Ensure user groups for device access
    users.groups.plugdev = {};
    users.users = {
      mcamp = {
        extraGroups = ["plugdev" "input"];
      };
    };
    # Chromium for usevia.app + fix the portal error
    programs.chromium = {
      enable = true;
      extraOpts = {
        "EnableExperimentalWebPlatformFeatures" = true;
        "WebHIDAllowed" = true;
        "DefaultWebHIDGuardSetting" = 1; # Allow WebHID by default
      };
    };
    services.dbus.enable = true;
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
    # Make sure OpenGL stack is wired for Electron/Chromium apps
    hardware.opengl.enable = true;
  };
}
