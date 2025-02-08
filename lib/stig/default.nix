{ lib, inputs, ... }:
with lib; rec {
  mkStigModule = { name, srgList, cciList, config, stigConfig }:
    let cfg = config.campground.stig.${name};
    in {
      options.campground.stig.${name} = with types; {
        enable = lib.campground.mkBoolOpt config.campground.stig.enable
          "Enable/Disable ${name}";
        justification =
          lib.campground.mkOpt (listOf str) [ ] "Reasons why this is disabled.";
      };

      config = {
        campground.stig.active.${name} = mkIf cfg.enable {
          srg = srgList;
          cci = cciList;
          config = stigConfig;
        };

        campground.stig.inactive.${name} = mkIf (!cfg.enable) {
          srg = srgList;
          cci = cciList;
          justification = cfg.justification;
        };

        assertions = [{
          assertion = cfg.enable != true -> (cfg.justification != [ ]);
          message =
            "You must provide at least one justification if campground.stig.${name} is disabled.";
        }];
      };
    };
}
