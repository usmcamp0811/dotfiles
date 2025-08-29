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
    # VIA/Vial udev rules (use package-provided rules with correct priority)
    services.udev.packages = [pkgs.via pkgs.vial];

    # Fallback (keeps WebHID happy if you’re not using the pkgs above)
    services.udev.extraRules = ''
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess"
    '';

    # Chromium for usevia.app + fix the portal error
    programs.chromium.enable = true;
    xdg.portal.enable = true;
    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];

    # (optional) Make sure OpenGL stack is wired for Electron/Chromium apps
    hardware.opengl.enable = true;
  };
}
