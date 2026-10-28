{
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  # markdown-it-py, mdit-py-plugins and pygments are only for `okf site`.
  python-env = pkgs.python3.withPackages (ps: [
    ps.pyyaml
    ps.markdown-it-py
    ps.mdit-py-plugins
    ps.pygments
  ]);

  toolSrc = fileset.toSource {
    root = ./.;
    fileset = fileset.unions [./okf.py ./okf_site.py ./site];
  };

  okf = pkgs.writeShellApplication {
    name = "okf";
    text = ''
      export PYTHONDONTWRITEBYTECODE=1
      exec ${python-env}/bin/python ${toolSrc}/okf.py "$@"
    '';
    meta = with lib; {
      description = "Check, migrate, index and publish Open Knowledge Format (OKF) v0.2 bundles";
      homepage = "https://github.com/GoogleCloudPlatform/open-knowledge-format";
      license = licenses.asl20;
      mainProgram = "okf";
    };
  };

  mermaid = pkgs.fetchurl {
    url = "https://unpkg.com/mermaid@11.12.0/dist/mermaid.min.js";
    hash = "sha256-B+N9+pezN8zIU2XVft35m5cG8J2ztZsmDQMzsjs0PEs=";
  };

  # Roboto (body) and Space Grotesk (headings), Latin subsets as woff2 from @fontsource, both
  # under the SIL Open Font License. style.css declares them with relative urls; they are copied
  # into the site, so nothing is fetched at view time. Without them pages use system fonts.
  fontFile = family: version: weight: hash:
    pkgs.fetchurl {
      url = "https://unpkg.com/@fontsource/${family}@${version}/files/${family}-latin-${weight}-normal.woff2";
      inherit hash;
    };
  fonts = pkgs.linkFarm "okf-fonts" [
    {name = "roboto-400.woff2"; path = fontFile "roboto" "5.3.0" "400" "sha256-QlwHE6gXb5InPTeFmcfqxX3n+vq9S9DtRXtw64+A03E=";}
    {name = "roboto-500.woff2"; path = fontFile "roboto" "5.3.0" "500" "sha256-W8w6oYDn8m9kPNWyYhzXwt4ZPQZh2ROpSv09SIGno0s=";}
    {name = "roboto-700.woff2"; path = fontFile "roboto" "5.3.0" "700" "sha256-udZtFwgVb3Za2lGTm8JO0lna+mnrYxs25ENoD+nhWHk=";}
    {name = "space-grotesk-500.woff2"; path = fontFile "space-grotesk" "5.3.0" "500" "sha256-GxqBMdnt+XXZ3s7oHi8r9QSBL3pPSY5VAPKKYT4i5kw=";}
    {name = "space-grotesk-700.woff2"; path = fontFile "space-grotesk" "5.3.0" "700" "sha256-NfiuxWz9XL/bA8xoczpUoLBbs2F//NX9MyutwLBFylU=";}
  ];

  # Build a static website from OKF bundles, plus a launcher that opens it.
  #
  #   pkgs.fmf.okf.mkSite {
  #     name = "my-docs";
  #     src = ./.;                 # a tree that contains the bundles
  #     bundles = ["docs" "modules"];
  #   }
  #
  # `nix run` on the result opens the site; the pages are in share/<name>.
  mkSite = {
    name,
    src,
    bundles,
    title ? "Knowledge",
    subtitle ? "Notes, runbooks and reference, read from their source files.",
    start ? null,
    exclude ? [],
    theme ? "navy",
    withMermaid ? true,
  }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = "0";
      dontUnpack = true;
      nativeBuildInputs = [okf];

      # The build fails if any page links to a file the site does not contain.
      installPhase = ''
        runHook preInstall

        okf site build \
          --out "$out/share/${name}" \
          --title ${escapeShellArg title} \
          --subtitle ${escapeShellArg subtitle} \
          --theme ${escapeShellArg theme} \
          ${optionalString withMermaid "--mermaid ${escapeShellArg mermaid}"} \
          ${optionalString (start != null) "--start ${escapeShellArg start}"} \
          ${concatMapStringsSep " " (pattern: "--exclude ${escapeShellArg pattern}") exclude} \
          ${concatMapStringsSep " " (bundle: escapeShellArg "${src}/${bundle}") bundles}

        mkdir -p "$out/share/${name}/assets/fonts"
        cp -L ${fonts}/*.woff2 "$out/share/${name}/assets/fonts/"

        install -Dm755 ${./launch.sh} "$out/bin/${name}"
        substituteInPlace "$out/bin/${name}" \
          --replace-fail "@name@" ${escapeShellArg name} \
          --replace-fail "@site@" "$out/share/${name}" \
          --replace-fail "@python@" "${python-env}/bin/python"

        runHook postInstall
      '';

      meta = {
        description = "${title}: OKF bundles as a static website";
        mainProgram = name;
        platforms = platforms.unix;
      };
    };
in
  okf.overrideAttrs (old: {
    passthru = (old.passthru or {}) // {inherit mkSite python-env mermaid;};
  })
