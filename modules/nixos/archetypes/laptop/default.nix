{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.archetypes.laptop;
in
{
  options.campground.archetypes.laptop = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable the laptop archetype.";
  };

  config = mkIf cfg.enable {

    services.logind.lidSwitch = "ignore";

    services.tlp = {
        enable = true;
        settings = {
          TLP_DEFAULT_MODE = "BAT";
          TLP_PERSISTENT_DEFAULT = 1;
        };
     };

    campground = {
      suites = {
        common = enabled;
        desktop = enabled;
        development = enabled;
      };
      system = {
        wifi = {
          enable = true;
          networks = {
            SkyNet = {
              ssid = "SkyNet";
            };
            SkyNet5 = {
              ssid = "SkyNet5";
            };
            SkyNet6 = {
              ssid = "SkyNet2.0";
            };
          };
        };
      };
    };
  };
}
