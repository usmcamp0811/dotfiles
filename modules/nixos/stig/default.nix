{ lib, config, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.stig;
  # allStigs = removeAttrs cfg [ "enable" ];
  # activeStigs = filterAttrs (_: v: v.enable or false) allStigs;
  # inactiveStigs = filterAttrs (_: v: !(v.enable or false)) allStigs;
  #
  # aggregateValues = key:
  #   unique
  #     (concatLists (map (stig: stig.${key} or [ ]) (attrValues activeStigs)));
  #
  # # Collect values but DO NOT merge yet
  # aggregatedConfigs = map (stig: stig.config or { }) (attrValues activeStigs);
  #
  # # Lazy merging function - only executes when needed
  # mergedConfig = mkMerge aggregatedConfigs;
in
{

  options.campground.stig = {
    enable = mkEnableOption "Campground STIG aggregation";
    active = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Aggregated active STIGs.";
      internal = true;
    };
    inactive = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Aggregated inactive STIGs.";
      internal = true;
    };
  };
  config = { };
}
