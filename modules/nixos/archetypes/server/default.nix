{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.archetypes.server;
in
{
  options.campground.archetypes.server = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable the server archetype.";
    worker = mkBoolOpt false "Is this a K8s Worker?";
    controller = mkBoolOpt false "Is this a K8s Controller?";
    hostId = mkOpt str "" "ZFS Host ID";
  };

  config = mkIf cfg.enable {
    campground = {
      suites = {
        common = enabled;
      };
      system = {
        zfs = {
          enable = true;
          hostId = cfg.hostId;
          keyfile-url = "http://10.8.0.1:1234/zfs-keyfile";
        };
        passwds = enabled;
      };
      services = {
        k0sworker = {
          enable = cfg.worker;
        };
        k0scontroller = {
          enable = cfg.controller;
        };
      };
    };
  };
}
