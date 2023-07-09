{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.internal;
let cfg = config.campground.home;
in
{
  imports = with inputs; [
    home-manager.nixosModules.home-manager
  ];

# TODO: Whats this.. feel like this might be something i should edit
#   options.campground.home = with types; {
#     file = mkOpt attrs { }
#       "A set of files to be managed by home-manager's <option>home.file</option>.";
#     configFile = mkOpt attrs { }
#       "A set of files to be managed by home-manager's <option>xdg.configFile</option>.";
#     extraOptions = mkOpt attrs { } "Options to pass directly to home-manager.";
#   };

  config = {
    # campground.home.extraOptions = {
    #   # home.stateVersion = config.system.stateVersion;
    #   # home.file = mkAliasDefinitions options.campground.home.file;
    #   # xdg.enable = true;
    #   # xdg.configFile = mkAliasDefinitions options.campground.home.configFile;
    # };

    # home-manager = {
    #   useUserPackages = true;

    #   users.${config.campground.user.name} =
    #     mkAliasDefinitions options.campground.home.extraOptions;
    # };
  };
}
