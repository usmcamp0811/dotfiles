{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.system.nic-teaming;
  allNICs = lib.attrNames config.networking.interfaces;

in
{
  options.campground.system.nic-teaming = with types; {
    enable = mkBoolOpt false "Enable NIC Teaming";
    ip = mkOpt str "192.168.1.123" "IP to bind team to";
    bondNICs = mkOpt (lib.types.listOf lib.types.str) [] "The NICs to bond";
  };

  config = mkIf cfg.enable {
    networking.useDHCP = false;

    systemd.network = {
      netdevs = {
        bond0 = {
          netdevConfig = {
            Kind = "bond";
            Name = "bond0";
          };
          bondConfig = {
            Mode = "802.3ad";
            TransmitHashPolicy = "layer3+4";
          };
        };
      };
      
      networks = lib.listToAttrs (map (nic: {
        name = "${nic}";
        value = {
          matchConfig.Name = "${nic}";
          networkConfig.Bond = "bond0";
        };
      }) cfg.bondNICs // [{
        name = "bond0";
        value = {
          matchConfig.Name = "bond0";
          networkConfig.Address = [ "${cfg.ip}/24" ];
          networkConfig.LinkLocalAddressing = "no";
        };
      }]);
    };
  };
}

