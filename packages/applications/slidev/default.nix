{ lib
, pkgs
,
}:
with lib; let
  versions = {
    v0_49_29 = {
      version = "0.49.29";
      rev = "v0.49.29";
      srcHash = "sha256-bOSIJTzPMyS+wbJsLVaMw/wicbsgQADEOyQQjU8MKWw=";
      depsHash = "sha256-18/6hNsRq0hl1UXY6cchuIEVWTbCiZJG33QHDvnXS1A=";
    };
    v0_50_0 = {
      version = "0.50.0";
      rev = "v0.50.0";
      srcHash = "sha256-8LP7bAFWJAxd17u77aqX+j0mqTw59AODlrqot8np21g=";
      depsHash = "sha256-M9wqO+V5r2+PlxRMBe47fULTyaaeDWq45rR6XtKPsBw=";
    };
    v51_6_0 = {
      version = "51.6.0";
      rev = "v51.6.0";
      srcHash = "sha256-8LP7bAFWJAxd17u77aqX+j0mqTw59AODlrqot8np21g=";
      depsHash = "sha256-M9wqO+V5r2+PlxRMBe47fULTyaaeDWq45rR6XtKPsBw=";
    };
  };

  buildSlidev = name: cfg:
    pkgs.stdenv.mkDerivation (finalAttrs: {
      pname = "slidev";
      version = cfg.version;

      src = pkgs.fetchFromGitHub {
        owner = "slidevjs";
        repo = "slidev";
        rev = cfg.rev;
        hash = cfg.srcHash;
      };

      nativeBuildInputs = [ pkgs.nodejs pkgs.pnpm_9.configHook pkgs.makeWrapper ];

      pnpmDeps = pkgs.pnpm_8.fetchDeps {
        pname = "slidev";
        version = cfg.version;
        src = finalAttrs.src;
        hash = cfg.depsHash;
      };

      buildPhase = ''
        runHook preBuild
        pnpm --filter @slidev/cli build
        pnpm --filter @slidev/parser build
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r packages $out/packages
        cp -r node_modules $out/node_modules
        makeWrapper ${pkgs.nodejs}/bin/node $out/bin/slidev \
          --set NODE_PATH "$out/node_modules" \
          --add-flags "$out/packages/slidev/bin/slidev.mjs"
        runHook postInstall
      '';

      meta = {
        description = "Presentation Slides for Developers";
        homepage = "https://sli.dev/";
        changelog = "https://github.com/slidevjs/slidev/releases/tag/v${cfg.version}";
        license = licenses.mit;
        mainProgram = "slidev";
      };
    });

  all = lib.mapAttrs buildSlidev versions;

  # Choose the latest version for default
  latest = all.v0_50_0;
in
latest // all
