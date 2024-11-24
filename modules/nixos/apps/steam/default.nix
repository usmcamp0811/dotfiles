{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.apps.steam;
in {
  options.campground.apps.steam = with types; {
    enable = mkBoolOpt false "Whether or not to enable support for Steam.";
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    programs.steam.remotePlay.openFirewall = true;

    hardware.steam-hardware.enable = true;

    # Enable GameCube controller support.
    services.udev.packages = [ pkgs.dolphin-emu ];

    environment.systemPackages = with pkgs; [
      campground.steam
      steamtinkerlaunch
    ];

    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
    };
  };
}
