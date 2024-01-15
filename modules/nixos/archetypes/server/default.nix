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
        ntp = enabled;
        docker = enabled;
        ldap-client = enabled;
        tang = enabled;
        k0sworker = {
          enable = cfg.worker;
        };
        k0scontroller = {
          enable = cfg.controller;
        };
        openssh = { 
          authorizedKeys = [ 
            "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          ];
        };
      };
    };
  };
}
