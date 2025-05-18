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

  mkCompliantPackage =
    { pkg
    , rmfMeta
    , knownCompliantControls ? [ ]
    ,
    }:
    let
      wrapped = wrapWithRMF { inherit pkg rmfMeta; };
    in
    assert checkRMFCompliance
      {
        pkg = wrapped;
        inherit knownCompliantControls;
      }; wrapped;

  checkRMFCompliance =
    { pkg
    , knownCompliantControls ? [ ]
    ,
    }:
    builtins.trace "Running RMF compliance check for ${pkg.pname or "<unknown>"}" (
      let
        meta = pkg.meta.rmf or { };
        required = meta.controls or { };
        controls = builtins.attrNames required;

        unmet =
          builtins.filter
            (
              c:
                !(
                  builtins.elem required.${c}.status [ "met" "waived" ]
                  && builtins.elem c knownCompliantControls
                )
            )
            controls;

        _ =
          lib.asserts.assertMsg
            (builtins.all
              (
                c:
                required.${c}.status
                == "met"
                || required.${c} ? justification
              )
              controls)
            "Each non-met RMF control must include a justification.";
      in
      if unmet == [ ]
      then true
      else throw "Package ${pkg.pname or "<unknown>"} fails RMF check: unmet controls ${builtins.toString unmet}"
    );
  mkRmfModuleFromPackage =
    { name
    , pkg
    , config
    ,
    }:
    let
      controls = pkg.meta.rmf.controls or { };

      moduleEntries =
        lib.mapAttrsToList
          (controlName: control:
            let
              controlPath = [ "campground" "rmf" name controlName ];
              cfg = lib.getAttrFromPath controlPath config;
              pkgEnable = config.campground.rmf.${name}.enable or false;
              effectiveEnable = cfg.enabled or pkgEnable;
              forceAttrs = lib.mapAttrsRecursive (_: v: lib.mkForce v) (control.config or { });
            in
            {
              options = {
                campground.rmf.${name}.${controlName} = {
                  enabled = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable/Disable control ${controlName} for ${name}";
                  };
                  justification = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Justification for disabling ${controlName}";
                  };
                };
              };
              config = {
                config = lib.mkMerge [
                  (lib.mkIf effectiveEnable forceAttrs)

                  {
                    campground.controls.active.${name}.${controlName} = lib.mkIf effectiveEnable {
                      srg = control.srg or [ ];
                      cci = control.cci or [ ];
                      config = control.config or { };
                    };

                    campground.controls.inactive.${name}.${controlName} = lib.mkIf (!effectiveEnable) {
                      srg = control.srg or [ ];
                      cci = control.cci or [ ];
                      justification = cfg.justification;
                      config = control.config or { };
                    };
                  }

                  {
                    assertions = [
                      {
                        assertion = (!effectiveEnable) -> (cfg.justification != [ ]);
                        message = "Must justify disabling ${controlName} for ${name}.";
                      }
                    ];
                  }
                ];
              };
            })
          controls;

      optionsList = map (entry: entry.options) moduleEntries;

      configList = map (entry: entry.config) moduleEntries;
    in
    {
      options =
        {
          campground.rmf.${name}.enable = lib.mkEnableOption "Enable all controls for ${name}";
        }
        // lib.foldl (acc: opt: acc // opt) { } optionsList;

      config = lib.mkMerge (map (entry: entry.config) moduleEntries);
    };
}
