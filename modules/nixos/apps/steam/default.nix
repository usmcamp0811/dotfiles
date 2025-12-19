{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.apps.steam;
in {
  options.fmf.apps.steam = with types; {
    enable = mkBoolOpt false "Whether or not to enable support for Steam.";
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    programs.steam.remotePlay.openFirewall = true;

    hardware.steam-hardware.enable = true;

    # Enable GameCube controller support.
    services.udev.packages = [ pkgs.dolphin-emu ];

    environment.systemPackages = with pkgs; [
      fmf.steam
      steamtinkerlaunch
    ];

    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
    };
  };
}
