{ options, config, lib, ... }:
with lib;
with lib.namespace-change-me; {
  options.namespace-change-me.home = with types; {
    file = mkOpt attrs { }
      (mdDoc "A set of files to be managed by home-manager's `home.file`.");
    configFile = mkOpt attrs { } (mdDoc
      "A set of files to be managed by home-manager's `xdg.configFile`.");
    extraOptions = mkOpt attrs { } "Options to pass directly to home-manager.";
  };

  config = {
    namespace-change-me.home.extraOptions = {
      home.stateVersion = config.system.stateVersion;
      home.file = mkAliasDefinitions options.namespace-change-me.home.file;
      xdg.enable = true;
      xdg.configFile =
        mkAliasDefinitions options.namespace-change-me.home.configFile;
    };

    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;

      users.${config.namespace-change-me.user.name} =
        mkAliasDefinitions options.namespace-change-me.home.extraOptions;
    };
  };
}
