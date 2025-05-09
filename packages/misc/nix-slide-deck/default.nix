{ pkgs
, inputs
, ...
}:
let
  mkSlide =
    { lib
    , stdenv
    , slidev
    , markdown
    , themes
    , slides
    , assets ? [ ]
    , urlBase ? "/"
    ,
    }:
    pkgs.stdenv.mkDerivation {
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
        runHook postInstall
      '';

      meta = {
        description = "Slidev Presentation SPA";
        homepage = "https://sli.dev/";
        license = lib.licenses.mit;
        maintainers = with lib.maintainers; [ ];
      };
    };
in
pkgs.neovim
