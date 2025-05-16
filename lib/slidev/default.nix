{ lib
, inputs
, ...
}: rec {
  # adapted from https://github.com/charles-bord/nix-forest-slides/tree/master
  mkSlide =
    { lib
    , stdenv
    , slidev
    , markdown
    , themes ? [ ]
    , slides ? [ ]
    , assets ? [ ]
    , urlBase ? "/"
    , extraNodePackages ? [ ]
    ,
    }:
    stdenv.mkDerivation {
      pname = "slidev-presentation";
      version = "0.1.0";
      src = ./.;

      nativeBuildInputs = [ slidev ];

      buildInputs = extraNodePackages;

      buildPhase =
        let
          assetsGlobsStr =
            builtins.concatStringsSep " " (builtins.map (pkg: "${pkg}/*") assets);
          customThemeDirs = builtins.concatStringsSep "\n" (
            builtins.map
              (t: ''
                mkdir -p themes/${t.pname}
                cp -r ${t}/* themes/${t.pname}
              '')
              themes
          );
        in
        ''
          runHook preBuild

          mkdir themes

          ${customThemeDirs}

          chmod -R u+w themes/

          mkdir -p public/assets
          ${builtins.concatStringsSep "\n" (builtins.map (pkg: "cp -r ${pkg}/* public/assets/") assets)}

          mkdir -p slides
          ${builtins.concatStringsSep "\n" (builtins.map (pkg: "cp -r ${pkg}/* slides") slides)}

          mkdir -p node_modules

          # Copy all top-level packages from slidev
          cp -r ${slidev}/node_modules/* node_modules/

          # Inject extra packages (like sass-embedded)
          ${builtins.concatStringsSep "\n" (builtins.map (pkg: ''
              mkdir -p node_modules/${pkg.pname}
              cp -r ${pkg}/lib/node_modules/${pkg.pname}/* node_modules/${pkg.pname}/
            '')
            extraNodePackages)}

          cp ${markdown} ./slides.md
          slidev build --base "${urlBase}"

          runHook postBuild
        '';

      installPhase = ''
        runHook preInstall
        cp -r dist $out
        mkdir -p $out/themes
        cp -r themes $out/
        runHook postInstall
      '';

      meta = {
        description = "Slidev Presentation SPA";
        homepage = "https://sli.dev/";
        license = lib.licenses.mit;
        maintainers = with lib.maintainers; [ ];
      };
    };
  buildPnpmTheme =
    { pkgs
    , pname
    , version
    , src
    , depsHash
    , pnpm
    ,
    }:
    pkgs.stdenv.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = [ pkgs.nodejs pnpm.configHook ];

      pnpmDeps = pnpm.fetchDeps {
        inherit pname version src;
        hash = depsHash;
      };

      installPhase = ''
        runHook preInstall
        cp -r . $out
        runHook postInstall
      '';

      meta = {
        description = "Built theme ${pname}";
        license = lib.licenses.mit;
      };
    };

  buildNpmTheme =
    { pkgs
    , pname
    , version
    , src
    , depsHash ? null
    ,
    }:
    pkgs.buildNpmPackage {
      inherit pname version src;

      npmDepsHash = depsHash;

      env = {
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      };
      installPhase = ''
        runHook preInstall
        cp -r . $out
        runHook postInstall
      '';

      meta = {
        description = "Built theme ${pname}";
        license = pkgs.lib.licenses.mit;
      };
    };

  buildYarnTheme =
    { pkgs
    , pname
    , version
    , src
    , depsHash
    ,
    }:
    pkgs.mkYarnPackage {
      inherit pname version src;

      packageJSON = "${src}/package.json";
      yarnLock = "${src}/yarn.lock";

      outputHash = depsHash;

      installPhase = ''
        runHook preInstall
        cp -r . $out
        runHook postInstall
      '';

      meta = {
        description = "Built theme ${pname}";
        license = pkgs.lib.licenses.mit;
      };
    };
}
