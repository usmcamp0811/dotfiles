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
    , themes
    , # official prebuilt themes
      customThemes ? [ ]
    , # list of custom themes (built with pnpm)
      assets ? [ ]
    , urlBase ? "/"
    ,
    }:
    stdenv.mkDerivation {
      pname = "slidev-presentation";
      version = "0.1.0";
      src = ./.;

      nativeBuildInputs = [ slidev ];

      buildInputs = [ ];

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
              customThemes
          );
        in
        ''
          runHook preBuild

          mkdir themes
          cp -r ${themes}/packages/* themes/

          ${customThemeDirs}

          chmod -R u+w themes/

          mkdir -p public/assets
          ${builtins.concatStringsSep "\n" (builtins.map (pkg: "cp -r ${pkg}/* public/assets/") assets)}

          ln -s ${slidev}/node_modules node_modules

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
    ,
    }:
    pkgs.stdenv.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = [ pkgs.nodejs pkgs.pnpm_9.configHook ];

      pnpmDeps = pkgs.pnpm_9.fetchDeps {
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
}
