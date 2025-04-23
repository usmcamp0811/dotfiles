{ pkgs
, lib
, inputs
, ...
}:
let
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ./.;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pythonSet =
    (pkgs.callPackage inputs.pyproject-nix.build.packages {
      python = pkgs.python312;
    }).overrideScope (
      lib.composeManyExtensions [
        inputs.pyproject-build-systems.overlays.default
        overlay
      ]
    );
in
pythonSet.mkVirtualEnv "example-python-env" workspace.deps.default
