{ lib, ... }: rec {
  wrapWithRMF =
    { pkg
    , rmfMeta
    ,
    }:
    let
      controlSet = rmfMeta.mustMeetControls or { };
      justificationRequired =
        !(rmfMeta.approved or false)
        || builtins.any (c: controlSet.${c}.status != "met")
          (builtins.attrNames controlSet);

      _ =
        lib.asserts.assertMsg
          (!justificationRequired
            || builtins.all
            (
              c:
              controlSet.${c} ? justification
            )
            (builtins.attrNames controlSet))
          "Each non-met RMF control must include a justification.";
    in
    pkg.overrideAttrs (old: {
      meta =
        old.meta
        // {
          rmf = rmfMeta;
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
        required = meta.mustMeetControls or { };
        controls = builtins.attrNames required;

        unmet =
          builtins.filter
            (
              c:
                !(required.${c}.status
                  == "met"
                  && builtins.elem c knownCompliantControls)
            )
            controls;

        _ =
          lib.asserts.assertMsg
            (builtins.all
              (
                c:
                required.${c}.status == "met" || required.${c} ? justification
              )
              controls)
            "Each non-met RMF control must include a justification.";
      in
      if unmet == [ ]
      then true
      else throw "Package ${pkg.pname or "<unknown>"} fails RMF check: unmet controls ${builtins.toString unmet}"
    );
}
