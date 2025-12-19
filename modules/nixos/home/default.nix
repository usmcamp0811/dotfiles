{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; {
  # imports = with inputs; [
  #   home-manager.nixosModules.home-manager
  # ];

  options.fmf.home = with types; {
    file =
      mkOpt attrs { }
        (mdDoc "A set of files to be managed by home-manager's `home.file`.");
    configFile =
      mkOpt attrs { } (mdDoc
        "A set of files to be managed by home-manager's `xdg.configFile`.");
    extraOptions = mkOpt attrs { } "Options to pass directly to home-manager.";
  };

  config = {
    fmf.home.extraOptions = {
      home.stateVersion = config.system.stateVersion;
      home.file = mkAliasDefinitions options.fmf.home.file;
      xdg.enable = true;
      xdg.configFile = mkAliasDefinitions options.fmf.home.configFile;
    };

    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;

      users.${config.fmf.user.name} =
        mkAliasDefinitions options.fmf.home.extraOptions;
    };
  };
}
