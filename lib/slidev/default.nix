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
    , mytheme
    , assets ? [ ]
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
        in
        ''
          runHook preBuild

          mkdir themes
          cp -r ${themes}/packages/* themes/
          mkdir -p themes/slidev-theme-neversink
          cp -r ${mytheme}/* themes/slidev-theme-neversink
          chmod -R u+w themes/

          mkdir public
          ln -s ${assetsGlobsStr} public/

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
  buildTheme =
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
}
