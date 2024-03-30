{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.home;
in {
  # imports = with inputs; [
  #   home-manager.nixosModules.home-manager
  # ];

  options.campground.home = with types; {
    file = mkOpt attrs { }
      (mdDoc "A set of files to be managed by home-manager's `home.file`.");
    configFile = mkOpt attrs { } (mdDoc
      "A set of files to be managed by home-manager's `xdg.configFile`.");
    extraOptions = mkOpt attrs { } "Options to pass directly to home-manager.";
  };

  config = {
    campground.home.extraOptions = {
      home.stateVersion = config.system.stateVersion;
      home.file = mkAliasDefinitions options.campground.home.file;
      xdg.enable = true;
      xdg.configFile = mkAliasDefinitions options.campground.home.configFile;
    };

    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;

      users.${config.campground.user.name} =
        mkAliasDefinitions options.campground.home.extraOptions;
    };
  };
}
