{ lib, inputs, ... }:
with lib; rec {
  mkStigModule = { name, srgList ? [ ], cciList ? [ ], config, stigConfig }:
    let cfg = config.campground.stig.${name};
    in {
      options.campground.stig.${name} = with types; {
        enable = lib.campground.mkBoolOpt true "Enable/Disable ${name}";
        justification =
          lib.campground.mkOpt (listOf str) [ ] "Reasons why this is disabled.";
      };

      config = mkMerge [
        (mkIf cfg.enable stigConfig)

        {
          campground.stig = {
            active.${name} = mkIf cfg.enable {
              srg = srgList;
              cci = cciList;
              config =
                stigConfig; # Ensure `active.${name}.config = stigConfig` when enabled
            };

            inactive.${name} = mkIf (!cfg.enable) {
              srg = srgList;
              cci = cciList;
              justification = cfg.justification;
            };
          };

          assertions = [{
            assertion = cfg.enable -> (cfg.justification != [ ]);
            message =
              "You must provide at least one justification if campground.stig.${name} is disabled.";
          }];
        }
      ];
    };
}
