{ lib, inputs, ... }: rec {

  mkStigModule = name: desc: defaultEnable: srgList: cciList: extraConfig:
    { lib, config, pkgs, ... }:
    let cfg = config.campground.stig.${name};
    in {
      options.campground.stig.${name} = with types; {
        enable = mkBoolOpt defaultEnable desc;
        justification = mkOpt (nullOr str) null "Why you didn't enable this";
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
          message = "You must provide a justification if ${desc} is disabled.";
        }];
      };
    };
}
