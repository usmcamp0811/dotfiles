{
  lib,
  inputs,
}: rec {
  # Main function to create a jupyenv-compatible uv2nix Python environment
  mkUv2nixPythonEnv = {
    pkgs,
    # Required parameters
    workspaceRoot,
    projectName,
    # Optional parameters with sensible defaults
    python ? pkgs.python313,
    sourcePreference ? "wheel",
    deps ? "default",
    # Can be "default", "all", or specific dependency groups
    customOverrides ? (final: prev: {}),
    # Advanced options
    extraPassthru ? {},
    extraMeta ? {},
  }: let
    # 1. Load Project Workspace (parses pyproject.toml, uv.lock)
    workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
      inherit workspaceRoot;
    };

    # 2. Generate Nix Overlay from uv.lock (via workspace)
    uvLockedOverlay = workspace.mkPyprojectOverlay {
      inherit sourcePreference;
    };

    # 3. Construct the Final Python Package Set
    pythonSet = (pkgs.callPackage inputs.pyproject-nix.build.packages {inherit python;}).overrideScope (lib.composeManyExtensions [
      inputs.pyproject-build-systems.overlays.default # For build tools
      uvLockedOverlay # Your locked dependencies
      customOverrides # User-provided overrides
    ]);

    # 4. Get the project package
    thisProjectAsNixPkg = pythonSet.${projectName};

    # 5. Select dependencies based on deps parameter
    selectedDeps =
      if deps == "default"
      then workspace.deps.default
      else if deps == "all"
      then workspace.deps.all
      else if builtins.isList deps
      then deps
      else workspace.deps.${deps} or workspace.deps.default;

    # 6. Create the Python Runtime Environment
    appPythonEnv =
      pythonSet.mkVirtualEnv
      (thisProjectAsNixPkg.pname + "-env")
      selectedDeps;

    # Filter out non-package attributes to create pkgs
    nonPackageAttrs = ["python" "mkVirtualEnv" "resolveBuildSystem" "pythonPkgsBuildHost" "callPackage" "newScope" "overrideScope"];
    pythonPkgs = builtins.removeAttrs pythonSet nonPackageAttrs;
  in
    # Return the Python environment with full compatibility
    appPythonEnv.overrideAttrs (old: {
      meta =
        (old.meta or {})
        // {
          mainProgram = "python";
        }
        // extraMeta;

      # Fix jupyenv compatibility by removing non-executable files
      postFixup =
        (old.postFixup or "")
        + ''
          # Remove all non-executable files that jupyenv can't wrap
          find $out/bin -type f ! -executable -delete 2>/dev/null || true
        '';

      passthru =
        (old.passthru or {})
        // {
          # Make this look exactly like a standard Python interpreter
          inherit
            (pythonSet.python.passthru)
            executable
            pythonVersion
            version
            pythonAttr
            libPrefix
            sitePackages
            interpreter
            ;

          # Expose the underlying Python interpreter
          python = pythonSet.python;

          # Create a pkgs attribute that includes requiredPythonModules
          pkgs =
            pythonPkgs
            // {
              requiredPythonModules =
                pythonSet.python.passthru.requiredPythonModules or
                  python.pkgs.requiredPythonModules or
                    (ps: lib.concatMap (p: p.requiredPythonModules or []) ps);
            };

          # Provide withPackages method
          withPackages = pythonSet.python.withPackages;

          # Copy other standard Python interpreter attributes
          inherit (pythonSet.python.passthru) buildEnv isPy27 isPy38 isPy39 isPy310 isPy311 isPy312 isPy313;

          # Expose workspace for advanced usage
          inherit workspace pythonSet;
        }
        // extraPassthru;
    });

  # Helper function for common PySpark setup
  mkUv2nixPySparkEnv = args:
    mkUv2nixPythonEnv (args
      // {
        customOverrides = final: prev: let
          inherit (final) resolveBuildSystem;
        in
          {
            pyspark = prev.pyspark.overrideAttrs (old: {
              nativeBuildInputs =
                old.nativeBuildInputs
                ++ resolveBuildSystem {
                  setuptools = [];
                };
            });
          }
          // (args.customOverrides or (final: prev: {})) final prev;
      });

  # Helper function for data science environments
  mkUv2nixDataScienceEnv = args:
    mkUv2nixPythonEnv (args
      // {
        deps = args.deps or "all"; # Data science usually wants all dependencies
      });
}
