{ options
, config
, lib
, ...
}:
with lib;
with lib.campground; {
  # imports = with inputs; [
  #   home-manager.darwinModules.home-manager
  # ];

  options.campground.home = with types; {
    file =
      mkOpt attrs { }
        "A set of files to be managed by home-manager's <option>home.file</option>.";
    configFile =
      mkOpt attrs { }
        "A set of files to be managed by home-manager's <option>xdg.configFile</option>.";
    extraOptions = mkOpt attrs { } "Options to pass directly to home-manager.";
    homeConfig = mkOpt attrs { } "Final config for home-manager.";
  };

  config = {
    campground.home.extraOptions = {
      home.stateVersion = config.system.stateVersion;
      home.file = mkAliasDefinitions options.campground.home.file;
      xdg.enable = true;
      xdg.configFile = mkAliasDefinitions options.campground.home.configFile;
    };

    snowfallorg.user.${config.campground.user.name}.home.config =
      mkAliasDefinitions options.campground.home.extraOptions;

    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;

      # users.${config.campground.user.name} = args:
      #   mkAliasDefinitions options.campground.home.extraOptions;
    };
  };
}
