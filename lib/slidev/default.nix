{
  lib,
  inputs,
  ...
}: rec {
  # adapted from https://github.com/charles-bord/nix-forest-slides/tree/master
  mkSlide = {
    lib,
    stdenv,
    slidev,
    markdown,
    themes ? [],
    slides ? [],
    assets ? [],
    urlBase ? "/",
    extraNodePackages ? [],
    meta ? {},
  }:
    stdenv.mkDerivation {
      pname = "slidev-presentation";
      version = "0.1.0";
      src = ./.;

      nativeBuildInputs = [slidev];

      buildInputs = extraNodePackages;

      buildPhase = let
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
      in ''
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

      meta =
        {
          description = "Slidev Presentation SPA";
          homepage = "https://sli.dev/";
          license = lib.licenses.mit;
          maintainers = with lib.maintainers; [];
        }
        // meta;
    };
  buildPnpmTheme = {
    pkgs,
    pname,
    version,
    src,
    depsHash,
    pnpm,
    meta ? {},
  }:
    pkgs.stdenv.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = [pkgs.nodejs pnpm pkgs.pnpmConfigHook];

      pnpmDeps = pkgs.fetchPnpmDeps {
        inherit pname version src;
        hash = depsHash;
        fetcherVersion = 3;
      };

      installPhase = ''
        runHook preInstall
        cp -r . $out
        runHook postInstall
      '';

      meta =
        {
          description = "Built theme ${pname}";
          license = lib.licenses.mit;
        }
        // meta;
    };

  buildNpmTheme = {
    pkgs,
    pname,
    version,
    src,
    depsHash ? null,
    peerDeps ? {},
    meta ? {},
  }:
    pkgs.buildNpmPackage {
      inherit pname version src;
      npmDepsHash = depsHash;

      env = {
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      };

      preBuild = ''
        echo "Injecting peerDependencies..."
        tmpfile=$(mktemp)
        ${pkgs.jq}/bin/jq --argjson peerDeps '${builtins.toJSON peerDeps}' '
          .dependencies += $peerDeps
        ' package.json > $tmpfile
        mv $tmpfile package.json
      '';

      installPhase = ''
        runHook preInstall
        cp -r . $out
        runHook postInstall
      '';

      meta =
        {
          description = "Built theme ${pname}";
          license = pkgs.lib.licenses.mit;
        }
        // meta;
    };

  buildYarnTheme = {
    pkgs,
    pname,
    version,
    src,
    yarnNix,
    meta ? {},
  }: let
    themePkg = pkgs.stdenv.mkDerivation rec {
      inherit pname version;

      buildInputs = [
        (pkgs.yarn2nix-moretea.mkYarnPackage {
          inherit pname version src yarnNix;
          packageJSON = "${src}/package.json";
          yarnLock = "${src}/yarn.lock";
        })
      ];

      phases = ["installPhase"];

      installPhase = ''
        runHook preInstall
        mkdir -p $out/deps/${pname}
        cp -r ${builtins.head buildInputs}/libexec/${pname}/* $out
        runHook postInstall
      '';

      meta = {
        description = "Raw theme build for ${pname}";
        license = pkgs.lib.licenses.mit;
      };
    };
  in
    pkgs.stdenv.mkDerivation {
      inherit pname version;
      src = themePkg;

      phases = ["installPhase"];

      installPhase = ''
        mkdir -p $out
        ln -s ${themePkg}/deps/${pname}/* $out/
      '';

      meta =
        {
          description = "Slidev theme ${pname}";
          license = pkgs.lib.licenses.mit;
        }
        // meta;
    };

  makeIndexPage = {
    pkgs,
    slides,
  }:
    pkgs.writeTextFile {
      name = "index.html";
      text = ''
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>Slide Decks</title>
          <style>
            body {
              font-family: system-ui, sans-serif;
              background: linear-gradient(145deg, #1e1e2f, #2e2e3f);
              color: #eee;
              margin: 0;
              padding: 2rem;
              display: flex;
              flex-direction: column;
              align-items: center;
            }
            h1 {
              font-size: 2.5rem;
              margin-bottom: 1.5rem;
            }
            ul {
              list-style: none;
              padding: 0;
              max-width: 600px;
              width: 100%;
            }
            li {
              margin: 1rem 0;
            }
            a {
              display: block;
              padding: 1rem 1.5rem;
              border-radius: 0.5rem;
              background: #3a3a5a;
              color: #fff;
              text-decoration: none;
              font-size: 1.2rem;
              transition: background 0.3s ease;
            }
            a:hover {
              background: #5a5acc;
            }
          </style>
        </head>
        <!-- Matomo -->
        <script>
          var _paq = window._paq = window._paq || [];
          /* tracker methods like "setCustomDimension" should be called before "trackPageView" */
          _paq.push(['trackPageView']);
          _paq.push(['enableLinkTracking']);
          (function() {
            var u="https://matomo.aicampground.com/";
            _paq.push(['setTrackerUrl', u+'matomo.php']);
            _paq.push(['setSiteId', '5']);
            var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
            g.async=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);
          })();
        </script>
        <!-- End Matomo Code -->
        <body>
          <h1>📚 Slide Decks</h1>
          <ul>
          ${
          builtins.concatStringsSep "\n" (
            builtins.map
            (
              slideName: let
                title = lib.getAttr "meta" (lib.getAttr slideName slides) // {};
              in
                "<li><a href=\"" + slideName + "/\">" + title.title + "</a></li>"
            )
            (builtins.attrNames slides)
          )
        }
          </ul>
        </body>
        </html>
      '';
    };
}
