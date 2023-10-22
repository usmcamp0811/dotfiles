{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.system.nic-teaming;
  allNICs = lib.attrNames config.networking.interfaces;
  teamNICs = builtins.filter (nic: nic != "lo") allNICs;
in
{
  options.campground.system.nic-teaming = with types; {
    enable = mkBoolOpt false "Enable NIC Teaming";
    ip = mkOpt str "192.168.1.123";
  };

  config = mkIf cfg.enable {
    networking.useDHCP = false;

    networking.interfaces = {
      team0 = {
        virtual = true;
        useDHCP = false;
      };
    };

    networking.teaming.interfaces = teamNICs;

    networking.teaming.runner = {
      name = "roundrobin";
    };

    systemd.network = {
      "10-team0.netdev" = {
        netdev = {
          Name = "team0";
          Kind = "team";
        };
      };

      "20-team0.network" = {
        network = {
          Address = "${cfg.ip}/24";
          Team = "team0";
        };
      };
    };
  };
}

