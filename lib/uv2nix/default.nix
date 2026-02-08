{
  lib,
  inputs,
}: rec {
  # Main function to create a jupyenv-compatible uv2nix Python environment
  mkUv2nixPythonEnv = {
    # Required parameters
    pkgs,
    workspaceRoot,
    projectName ? null, # Now optional - will auto-detect from workspace if not provided
    # Optional parameters with sensible defaults
    python ? pkgs.python313,
    sourcePreference ? "wheel",
    deps ? "default", # Can be "default", "all", or specific dependency groups
    customOverrides ? (final: prev: {}),
    envName ? null, # Custom environment name, defaults to projectName + "-env"
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
    pythonSet = (pkgs.callPackage inputs.pyproject-nix.build.packages {inherit python;})
      .overrideScope (lib.composeManyExtensions [
      inputs.pyproject-build-systems.overlays.default # For build tools
      uvLockedOverlay # Your locked dependencies
      customOverrides # User-provided overrides
    ]);

    # 4. Auto-detect project name if not provided
    detectedProjectName =
      if projectName != null
      then projectName
      else if workspace ? project && workspace.project ? name
      then workspace.project.name
      else "python-env";

    # 5. Get the project package (if it exists)
    thisProjectAsNixPkg =
      if pythonSet ? ${detectedProjectName}
      then pythonSet.${detectedProjectName}
      else null;

    # 6. Determine environment name
    finalEnvName =
      if envName != null
      then envName
      else if thisProjectAsNixPkg != null
      then "${thisProjectAsNixPkg.pname}-env"
      else "${detectedProjectName}-env";

    # 7. Select dependencies based on deps parameter
    selectedDeps =
      if deps == "default"
      then workspace.deps.default
      else if deps == "all"
      then workspace.deps.all
      else if builtins.isList deps
      then deps
      else workspace.deps.${deps} or workspace.deps.default;

    # 8. Parse pyproject.toml to find the main script
    pyprojectPath = workspaceRoot + "/pyproject.toml";
    pyprojectContent =
      if builtins.pathExists pyprojectPath
      then builtins.readFile pyprojectPath
      else "";

    # Extract main program from pyproject.toml [project.scripts] section
    # This is a simplified parser - in practice you might want to use a proper TOML parser
    mainProgramFromPyproject = let
      lines = lib.splitString "\n" pyprojectContent;
      inScriptsSection =
        lib.foldl' (
          acc: line: let
            trimmed = lib.trim line;
          in
            if acc.inSection
            then
              if lib.hasPrefix "[" trimmed && trimmed != "[project.scripts]"
              then acc // {inSection = false;}
              else if lib.hasPrefix "#" trimmed || trimmed == ""
              then acc
              else let
                parts = lib.splitString "=" trimmed;
              in
                if builtins.length parts >= 2
                then
                  acc
                  // {
                    scripts =
                      acc.scripts
                      ++ [
                        {
                          name = lib.trim (builtins.head parts);
                          command = lib.trim (lib.concatStringsSep "=" (lib.tail parts));
                        }
                      ];
                  }
                else acc
            else if trimmed == "[project.scripts]"
            then acc // {inSection = true;}
            else acc
        ) {
          inSection = false;
          scripts = [];
        }
        lines;
    in
      if builtins.length inScriptsSection.scripts > 0
      then (builtins.head inScriptsSection.scripts).name
      else null;

    # 9. Create the Python Runtime Environment
    appPythonEnv =
      pythonSet.mkVirtualEnv
      finalEnvName
      selectedDeps;

    # Filter out non-package attributes to create pkgs
    nonPackageAttrs = ["python" "mkVirtualEnv" "resolveBuildSystem" "pythonPkgsBuildHost" "callPackage" "newScope" "overrideScope"];
    pythonPkgs = builtins.removeAttrs pythonSet nonPackageAttrs;

    # Create a wrapper script for the REPL
    replWrapper = pkgs.writeShellScript "${finalEnvName}-python" ''
      exec ${appPythonEnv}/bin/python "$@"
    '';
  in
    # Return the Python environment with full compatibility
    appPythonEnv.overrideAttrs (old: {
      meta =
        (old.meta or {})
        // {
          mainProgram =
            if mainProgramFromPyproject != null
            then mainProgramFromPyproject
            else "python";
        }
        // extraMeta;

      # Fix jupyenv compatibility and ensure main program availability
      postFixup =
        (old.postFixup or "")
        + ''
          # Remove all non-executable files that jupyenv can't wrap
          find $out/bin -type f ! -executable -delete 2>/dev/null || true

          # Ensure python is always available as the fallback
          if [[ ! -x "$out/bin/python" ]]; then
            ln -sf ${appPythonEnv}/bin/python $out/bin/python
          fi

          # Create a .python symlink for direct REPL access
          ln -sf ${appPythonEnv}/bin/python $out/bin/.python
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

          # Expose the environment's Python interpreter (not the base one)
          python =
            pkgs.runCommand "${finalEnvName}-python" {
              meta.mainProgram = "python";
            } ''
              mkdir -p $out/bin
              ln -s ${appPythonEnv}/bin/python $out/bin/python
            '';

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
