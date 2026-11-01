# The React/Vite single-page app, built from upstream's package-lock.json.
{
  lib,
  buildNpmPackage,
  src,
  version,
  npmDepsHash ? "sha256-LRKOLaJpS8bYHVIrSjVTYP0hvK3oC0c8+F9JnL2nAeI=",
}:
buildNpmPackage {
  pname = "circuit-breaker-frontend";
  inherit version src npmDepsHash;

  # `npm run build` stamps the version from ../../VERSION, so keep the repository layout.
  sourceRoot = "${src.name}/apps/frontend";

  # Playwright and husky are development tools; never fetch browsers in the build.
  env = {
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    HUSKY = "0";
  };

  installPhase = ''
    runHook preInstall
    cp -r dist $out
    runHook postInstall
  '';

  meta.description = "Circuit Breaker web UI";
}
