{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.syncthing;
in
{
  options.fmf.services.syncthing = with types; {
    enable = mkBoolOpt false "Whether or not to enable syncthing.";
    user = mkOpt str "mcamp" "User name";
    # TODO: use variablese from config as defaults
    dataDir =
      mkOpt str "/home/mcamp/Documents" "Default folder for new synced folders";
    configDir =
      mkOpt str "/home/mcamp/.config/syncthing"
        "# Folder for Syncthing's settings and keys";
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = cfg.user;
      dataDir = cfg.dataDir;
      configDir = cfg.configDir;
    };
  };
}
