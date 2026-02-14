{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.fmf.hardware.via;
in {
  options.fmf.hardware.via = with types; {
    enable = mkEnableOption "Keychron Keyboards & Mice";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.via
    ];
    # VIA/Vial udev rules for VIA-compatible keyboards
    services.udev.extraRules = ''
      # Keychron keyboards
      # Your Keychron Link (3434:d030)
      KERNEL=="hidraw*", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="d030", MODE="0666", GROUP="plugdev", TAG+="uaccess"
      # General Keychron VIA-compatible devices
      KERNEL=="hidraw*", ATTRS{idVendor}=="3434", MODE="0666", GROUP="plugdev", TAG+="uaccess"
      # Ensure WebHID can access the device
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"

      # Framework Laptop 16 Keyboard modules
      # Framework Laptop 16 Keyboard Module - ANSI (32ac:0012)
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0012", TAG+="uaccess"
      # Framework Laptop 16 Numpad Module (32ac:0014)
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0014", TAG+="uaccess"
      # Let regular users open the hidraw node (what WebHID needs)
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="32ac", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"
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
      extraPortals = lib.mkDefault [pkgs.xdg-desktop-portal-gtk];
    };
    # Make sure OpenGL stack is wired for Electron/Chromium apps
    hardware.graphics.enable = true;
  };
}
