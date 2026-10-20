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
    theme ? "field-manual",
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

        install -Dm755 ${./launch.sh} "$out/bin/${name}"
        substituteInPlace "$out/bin/${name}" \
          --replace-fail "@name@" ${escapeShellArg name} \
          --replace-fail "@site@" "$out/share/${name}"

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
