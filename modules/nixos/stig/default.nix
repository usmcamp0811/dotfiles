{ lib, config, pkgs, ... }:

with lib;
with lib.campground;

let
  cfg = config.campground.stig;

  # List of known submodules
  submodules = [
    "account_expiry"
    "audit"
    "banner"
    "firewall"
    "login_attempts"
    "session_limit"
    "session_lock"
  ];

  # Function to get the source of a module
  getModuleSource = name:
    let
      moduleFiles = sourceFilesBySuffices (toString ./.)
        [ "${name}.nix" ]; # Find module files
    in
    if moduleFiles != [ ] then
      builtins.readFile (builtins.head moduleFiles)
    else
      "<source unavailable>";

  # Collect only the enabled modules and their individual SRGs/CCIs + source code
  enabledModules = builtins.listToAttrs (map
    (name:
      let subCfg = getAttr name config.campground.stig;
      in {
        name = name;
        value =
          if subCfg.enable then {
            srg = subCfg.srg or [ ];
            cci = subCfg.cci or [ ];
            source = getModuleSource name;
          } else
            null;
      })
    submodules);

  # Remove null entries from enabledModules
  filteredModules = filterAttrs (_: v: v != null) enabledModules;

  # Aggregate **only enabled modules'** SRGs and CCIs at the top level
  allSRGs = concatLists (map
    (name:
      let subCfg = getAttr name config.campground.stig;
      in if subCfg.enable then (subCfg.srg or [ ]) else [ ])
    submodules);

  allCCIs = concatLists (map
    (name:
      let subCfg = getAttr name config.campground.stig;
      in if subCfg.enable then (subCfg.cci or [ ]) else [ ])
    submodules);

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
          source = str;
        };
      }))
      { } "Enabled submodules with their SRGs, CCIs, and source code";
  };

  config = mkIf cfg.enable {
    # Set modules-enabled dynamically, ensuring each module only lists its own SRGs/CCIs + source code
    campground.stig.modules-enabled = filteredModules;

    # Set aggregated SRGs and CCIs
    campground.stig.srg = allSRGs;
    campground.stig.cci = allCCIs;

  };
}
