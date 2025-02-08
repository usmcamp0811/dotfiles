{ lib, inputs, ... }:
with lib; rec {
  mkStigModule = { name, srgList, cciList, config, extraConfig }:
    let cfg = config.campground.stig.${name};
    in {
      options.campground.stig.${name} = with types; {
        enable =
          lib.campground.mkBoolOpt config.campground.stig.enable "Enable/Disable ${name}";
        justification =
          lib.campground.mkOpt (nullOr str) null "Why you didn't enable this";
      };

      config = {
        campground.stig.active.${name} = mkIf cfg.enable {
          srg = srgList;
          cci = cciList;
          config = extraConfig;
        };

        campground.stig.inactive.${name} = mkIf (!cfg.enable) {
          srg = srgList;
          cci = cciList;
          justification = cfg.justification;
        };

        assertions = [{
          assertion = cfg.enable != true -> cfg.justification != null;
          message =
            "You must provide a justification if campground.stig.${name} is disabled.";
        }];
      };
    };
}
