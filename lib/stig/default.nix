{ lib, inputs, ... }:
with lib; rec {
  mkStigModule = { name, srgList ? [ ], cciList ? [ ], config, stigConfig }:
    let
      cfg = config.fmf.stig.${name};
      forceAttrs = attrs: mapAttrsRecursive (_: v: mkForce v) attrs;

    in
    {
      options.fmf.stig.${name} = with types; {
        enable = lib.fmf.mkBoolOpt config.fmf.stig.enable
          "Enable/Disable ${name}";
        justification =
          lib.fmf.mkOpt (listOf str) [ ] "Reasons why this is disabled.";
      };

      config = mkMerge [
        (mkIf cfg.enable (forceAttrs stigConfig))

        {
          fmf.stig = {
            active.${name} = mkIf cfg.enable {
              srg = srgList;
              cci = cciList;
              config = stigConfig;
            };

            inactive.${name} = mkIf (!cfg.enable) {
              srg = srgList;
              cci = cciList;
              justification = cfg.justification;
              config = stigConfig;
            };
          };

          assertions = [{
            assertion = (!cfg.enable && config.fmf.stig.enable == true)
              -> (cfg.justification != [ ]);
            message =
              "You must provide at least one justification if config.fmf.stig.${name} is disabled.";
          }];
        }
      ];
    };
}
