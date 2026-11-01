{
  lib,
  python3Packages,
  git,
  openssl,
  ...
}:
python3Packages.buildPythonApplication {
  pname = "circuit-breaker-sync";
  version = "0.1.0";
  pyproject = true;

  src = lib.cleanSource ./.;

  build-system = [python3Packages.setuptools];

  # The test-suite is the contract for the reconciler: it runs a fake of the
  # Circuit Breaker API (built from the real 0.4.6 OpenAPI document), so a
  # failing test fails the build.
  nativeCheckInputs = [
    python3Packages.pytestCheckHook
    openssl
  ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [git])
  ];

  pythonImportsCheck = ["cb_sync"];

  meta = {
    description = "Idempotent reconciler that syncs a Nix-flake-derived inventory into Circuit Breaker";
    license = lib.licenses.mit;
    mainProgram = "circuit-breaker-sync";
    platforms = lib.platforms.linux;
  };
}
