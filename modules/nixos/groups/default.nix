{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.groups;
in
{
  options.campground.groups = with types; {
    groups = mkOption {
      type = types.attrsOf types.int;
      default = {
        wheel = 10002;
        users = 10000;
        docker = 997;
        k8s = 999;
        libvirtd = 5001;
        networkmanager = 57;
        paperless = 317;
        audio = 501;
      };
      example = { wheel = 10; audio = 29; };
      description = "Groups and their corresponding IDs.";
    };
  };

  config = {
    users.groups = mapAttrs' (name: id: nameValuePair name { gid = id; }) cfg.groups;
  };
}


