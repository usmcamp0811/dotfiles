{ lib, ... }: rec {
  wrapWithRMF =
    { pkg
    , rmfMeta
    ,
    }:
    let
      controlSet = rmfMeta.controls or { };

      # All controls must be either met or waived (nothing left "open")
      allResolved =
        builtins.all
          (c:
            builtins.elem controlSet.${c}.status [ "met" "waived" ])
          (builtins.attrNames controlSet);

      _0 =
        lib.asserts.assertMsg allResolved
          "All RMF controls must be either 'met' or 'waived'.";

      justificationRequired =
        !(rmfMeta.approved or false)
        || builtins.any (c: controlSet.${c}.status != "met")
          (builtins.attrNames controlSet);

      _1 =
        lib.asserts.assertMsg
          (!justificationRequired
            || builtins.all
            (c: controlSet.${c} ? justification)
            (builtins.attrNames controlSet))
          "Each non-met RMF control must include a justification.";

      enforcedConfig =
        lib.foldlAttrs
          (
            name: acc: val:
              if builtins.elem val.status [ "met" "waived" ] && val ? config
              then lib.recursiveUpdate acc val.config
              else acc
          )
          { }
          controlSet;
    in
    pkg.overrideAttrs (old: {
      meta =
        old.meta or { }
        // {
          rmf = rmfMeta;
        };
      passthru =
        (old.passthru or { })
        // {
          enforcedConfig = enforcedConfig;
        };
    });

  mkRmfModuleFromPackage =
    { name
    , pkg
    , config
    ,
    }:
    let
      controls = pkg.meta.rmf.controls or { };

      # Utility to force all values
      forceAll = attrs: lib.mapAttrsRecursive (_: v: lib.mkForce v) attrs;

      # Build a module entry per control
      buildControlModule = controlName: control:
        let
          cfg = config.campground.rmf.${name}.${controlName};
          pkgEnabled = config.campground.rmf.${name}.enable or false;
          enabled = cfg.enabled or pkgEnabled;

          controlConfig = control.config or { };
          srg = control.srg or [ ];
          cci = control.cci or [ ];
        in
        {
          options = {
            ${controlName} = with lib.types; {
              enabled = lib.campground.mkBoolOpt true "Enable/Disable control ${controlName}";
              justification = lib.campground.mkOpt (listOf str) [ ] "Justification if disabled.";
            };
          };

          config = lib.mkMerge [
            (lib.mkIf enabled (forceAll controlConfig))

            {
              campground.controls.active.${name}.${controlName} = lib.mkIf enabled {
                inherit srg cci config;
              };

              campground.controls.inactive.${name}.${controlName} = lib.mkIf (!enabled) {
                inherit srg cci;
                justification = cfg.justification;
                config = controlConfig;
              };
            }

            {
              assertions = [
                {
                  assertion = (!enabled) -> (cfg.justification != [ ]);
                  message = "You must justify disabling ${controlName} for ${name}.";
                }
              ];
            }
          ];
        };

      entries = lib.mapAttrsToList buildControlModule controls;

      # Merge control-level options into a single attrset under campground.rmf.${name}
      controlOptions =
        lib.mergeAttrsList (map (e: e.options) entries);

      controlConfigs =
        map (e: e.config) entries;
    in
    {
      options = {
        campground.rmf.${name} =
          {
            enable = lib.campground.mkBoolOpt true "Enable all controls for ${name}";
          }
          // controlOptions;
      };

      config = lib.mkMerge controlConfigs;
    };
}
