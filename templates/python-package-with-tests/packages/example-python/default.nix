{ pkgs, lib, uv2nix, pyproject-nix, pyproject-build-systems, ... }:
let
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

  # Temporary package set without overrides
  basePythonSet = (pkgs.callPackage pyproject-nix.build.packages {
    python = pkgs.python312;
  }).overrideScope (lib.composeManyExtensions [
    pyproject-build-systems.overlays.default
    overlay
  ]);

  # Virtualenv and pytestTest are based on the unmodified basePythonSet
  virtualenv = basePythonSet.mkVirtualEnv "testing-pytest-env" {
    example-python = [ "test" ];
  };

  pytestTest = pkgs.stdenv.mkDerivation {
    name = "${basePythonSet.example-python.name}-pytest";
    inherit (basePythonSet.example-python) src;
    nativeBuildInputs = [ virtualenv ];
    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      pytest --cov tests --cov-report html
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mv htmlcov $out
      runHook postInstall
    '';
  };

  # Now define the final python set with overrideAttrs
  pythonSet = basePythonSet.overrideScope (final: prev: {
    example-python = prev.example-python.overrideAttrs (old: {
      doCheck = true;
      nativeCheckInputs = [ virtualenv ];
      checkPhase = ''
        runHook preCheck
        pytest --cov tests --cov-report html
        runHook postCheck
      '';
      passthru = (old.passthru or { }) // { tests = { pytest = pytestTest; }; };
    });
  });

  pyapp = pythonSet.mkVirtualEnv "example-python-env" workspace.deps.default;
in {
  pythonSets = { "${pkgs.system}" = pythonSet; };
  default = pyapp;
  python = pythonSet.python;
}
