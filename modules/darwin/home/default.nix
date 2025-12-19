{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; {
  # imports = with inputs; [
  #   home-manager.darwinModules.home-manager
  # ];

  options.fmf.home = with types; {
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
    fmf.home.extraOptions = {
      home.stateVersion = config.system.stateVersion;
      home.file = mkAliasDefinitions options.fmf.home.file;
      xdg.enable = true;
      xdg.configFile = mkAliasDefinitions options.fmf.home.configFile;
    };

    snowfallorg.user.${config.fmf.user.name}.home.config =
      mkAliasDefinitions options.fmf.home.extraOptions;

    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;

      # users.${config.fmf.user.name} = args:
      #   mkAliasDefinitions options.fmf.home.extraOptions;
    };
  };
}
