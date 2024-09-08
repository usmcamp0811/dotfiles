{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.campground;
let
  cfg = config.campground.services.syncthing;
in
{
  options.campground.services.syncthing = with types; {
    enable = mkBoolOpt false "Whether or not to enable syncthing.";
  };

  config = mkIf cfg.enable {
    services = {
    #   syncthing = {
    #     enable = true;
    #     user = config.campground.user.name;
    #     dataDir = "/home/${config.campground.user.name}/Documents";
    #     configDir = "/home/${config.campground.user.name}/Documents/.config/syncthing";
    #     overrideDevices = true; # overrides any devices added or deleted through the WebUI
    #     overrideFolders = true; # overrides any folders added or deleted through the WebUI
    #     settings = {
    #       devices = {
    #         "butler" = {
    #           id = "";
    #         };
    #         "device2" = {
    #           id = "DEVICE-ID-GOES-HERE";
    #         };
    #       };
    #       folders = {
    #         "Documents" = {
    #           # Name of folder in Syncthing, also the folder ID
    #           path = "/home/myusername/Documents"; # Which folder to add to Syncthing
    #           devices = [
    #             "device1"
    #             "device2"
    #           ]; # Which devices to share the folder with
    #         };
    #         "Example" = {
    #           path = "/home/myusername/Example";
    #           devices = [ "device1" ];
    #           ignorePerms = false; # By default, Syncthing doesn't sync file permissions. This line enables it for this folder.
    #         };
    #       };
    #     };
    #   };
    # };
    services.syncthing = {
      enable = true;
      tray = {
        enable = false;
      };
      extraOptions = [ "--no-default-folder" ];
    };
  };
}
