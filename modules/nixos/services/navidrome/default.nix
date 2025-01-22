{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.navidrome;
in {
  options.campground.services.navidrome = {
    enable = mkEnableOption "Navidrome Music Server";

    package =
      mkOpt types.package pkgs.navidrome "The Navidrome package to use.";

    port = mkOpt types.int 4533 "Port to use for Navidrome.";
    address = mkOpt types.str "0.0.0.0" "Listen address for Navidrome.";
    user = mkOpt types.str "navidrome" "The user under which Navidrome runs.";
    group = mkOpt types.str "navidrome" "The group under which Navidrome runs.";
    openFirewall =
      mkOpt types.bool false "Whether to open the firewall for Navidrome.";
    enableInsightsCollector = mkOpt types.bool true
      "Enable anonymous insights collection for Navidrome.";
  };

  config = mkIf cfg.enable {
    # Use the provided NixOS module
    services.navidrome = {
      enable = true;
      package = cfg.package;
      settings = {
        Port = cfg.port;
        Address = cfg.address;
        EnableInsightsCollector = cfg.enableInsightsCollector;
      };
      user = cfg.user;
      group = cfg.group;
      openFirewall = cfg.openFirewall;
    };

    users = {
      users = {
        "${cfg.user}" = {
          group = "${cfg.group}";
          isSystemUser = true;
        };
      };
      groups = { "${cfg.group}" = { }; };
    };
  };
}
