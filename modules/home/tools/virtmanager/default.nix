{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.tools.virtmanager;
in {
  options.campground.tools.virtmanager = with types; {
    enable = mkBoolOpt false "Whether or not to enable Virt-manager.";
  };

  config = mkIf cfg.enable {
    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = ["qemu:///system"];
        uris = ["qemu:///system"];
      };
    };
  };
}
