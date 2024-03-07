{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.suites.hosting;
in
{
  options.campground.suites.hosting = with types; {
    enable = mkBoolOpt false "Whether or not to enable common hosting configuration.";
    interaface = mkOpt str "eno1" "Interface to use for the LAN Instance";
    lan-interface = mkOpt str cfg.interface "Interface to use for the LAN Instance";
    pub-interface = mkOpt str cfg.interface "Interface to use for the Public Instance";
  };

  config = mkIf cfg.enable {
    campground = {
      services = {
        keepalived = {
          enable = true;
          instances = {
            "pub-campground" = {
              interface = "enp3s0f1";
              ips = [ "10.8.0.69" ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 51;
            };
            "lan-campground" = {
              interface = "enp3s0f1";
              ips = [ "10.8.0.70" ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 52;
            };
          };
        };
      };
    };
  };
}
