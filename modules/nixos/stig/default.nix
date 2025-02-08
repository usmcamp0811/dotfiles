{ lib, config, pkgs, ... }:

with lib;
with lib.campground;

let
  cfg = config.campground.stig;

  # Extract values from `active` and `inactive`
  activeModules = attrValues (cfg.active or { });
  inactiveModules = attrValues (cfg.inactive or { });

  # Aggregate SRGs and CCIs separately for active and inactive modules
  activeSRGs = flatten (map (m: m.srg or [ ]) activeModules);
  activeCCIs = flatten (map (m: m.cci or [ ]) activeModules);
  inactiveSRGs = flatten (map (m: m.srg or [ ]) inactiveModules);
  inactiveCCIs = flatten (map (m: m.cci or [ ]) inactiveModules);

  # Extract and merge all active configurations
  mergedConfig =
    foldl' recursiveUpdate { } (map (m: m.config or { }) activeModules);

in
{
  options.campground.stig = with types; {
    enable = mkBoolOpt false "STIG the machine";
    active = mkOpt
      (submodule {
        options = {
          srg = mkOpt (listOf str) [ ]
            "Aggregated list of SRGs from enabled submodules";
          cci = mkOpt (listOf str) [ ]
            "Aggregated list of CCIs from enabled submodules";
          modules = mkOpt
            (attrsOf (submodule {
              options = {
                srg = listOf str;
                cci = listOf str;
                config = attrs;
              };
            }))
            { } "Enabled submodules with their SRGs, CCIs, and configurations.";
        };
      })
      { } "Aggregated details of active STIG submodules.";

    inactive = mkOpt
      (submodule {
        options = {
          srg = mkOpt (listOf str) [ ]
            "Aggregated list of SRGs from disabled submodules";
          cci = mkOpt (listOf str) [ ]
            "Aggregated list of CCIs from disabled submodules";
          modules = mkOpt
            (attrsOf (submodule {
              options = {
                srg = listOf str;
                cci = listOf str;
                justification = nullOr str;
              };
            }))
            { }
            "Disabled submodules with their SRGs, CCIs, and justifications.";
        };
      })
      { } "Aggregated details of inactive STIG submodules.";
  };

  config = mkIf cfg.enable {
    campground.stig = {
      active = {
        srg = activeSRGs;
        cci = activeCCIs;
      };
      inactive = {
        srg = inactiveSRGs;
        cci = inactiveCCIs;
      };
    };
  };
}
