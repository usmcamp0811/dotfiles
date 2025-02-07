{ lib, config, pkgs, ... }:

with lib;
with lib.campground;

let
  cfg = config.campground.stig;

  # Collect all active submodule configs
  activeModules = attrValues cfg.active;

  # Aggregate all SRGs and CCIs from active modules
  allSRGs = concatLists (map (m: m.srg or [ ]) activeModules);
  allCCIs = concatLists (map (m: m.cci or [ ]) activeModules);

  # Merge all active configurations
  mergedConfig =
    foldl' recursiveUpdate { } (map (m: m.config or { }) activeModules);

in
{
  options.campground.stig = with types; {
    enable = mkBoolOpt false "STIG the machine";
    srg =
      mkOpt (listOf str) [ ] "Aggregated list of SRGs from enabled submodules";
    cci =
      mkOpt (listOf str) [ ] "Aggregated list of CCIs from enabled submodules";
    active = mkOpt
      (attrsOf (submodule {
        options = {
          srg = listOf str;
          cci = listOf str;
          config = attrs;
        };
      }))
      { } "Enabled submodules with their SRGs, CCIs, and configurations.";
    inactive = mkOpt
      (attrsOf (submodule {
        options = {
          srg = listOf str;
          cci = listOf str;
          config = attrs;
        };
      }))
      { } "Disabled submodules with their SRGs, CCIs, and justifications.";
  };

  config = mkIf cfg.enable (recursiveUpdate
    {
      campground.stig = {
        active = activeModules;
        srg = allSRGs;
        cci = allCCIs;
      };
    }
    mergedConfig);
}
