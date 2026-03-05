{
  lib,
  pkgs,
  ...
}: let
  pname = "terraink";
  version = "0.2.0";

  lockfilePath = ./package-lock.json;

  src = pkgs.fetchFromGitHub {
    owner = "yousifamanuel";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-87DzA4hmGfWBLaVbrmbIHOlmfdRVxTFX/5bmsIk2C3A=";
  };

  srcWithLock =
    pkgs.runCommand "${pname}-src-${version}" {
      inherit src;
      lockfile = lockfilePath;
    } ''
      if [ ! -f "$lockfile" ]; then
        echo "ERROR: missing ${toString lockfilePath}"
        echo "Generate it with: npm install --package-lock-only (against v${version})"
        exit 1
      fi

      cp -r "$src" "$out"
      chmod -R u+w "$out"
      cp "$lockfile" "$out/package-lock.json"
    '';
in
  pkgs.buildNpmPackage {
    inherit pname version;
    src = srcWithLock;

    nativeBuildInputs = [pkgs.makeWrapper];

    # Update this after running prefetch-npm-deps
    npmDepsHash = "sha256-yXmueacim+22A+9XqCED9AZKRM0G1krNtOTIFvCOJbA=";

    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/${pname}"
      cp -r dist/* "$out/share/${pname}/"

      makeWrapper ${pkgs.caddy}/bin/caddy "$out/bin/${pname}" \
        --add-flags "file-server --root $out/share/${pname} --listen :4173"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Generate printable custom map posters";
      homepage = "https://github.com/yousifamanuel/terraink";
      license = licenses.mit;
      mainProgram = pname;
      platforms = platforms.linux ++ platforms.darwin;
    };
  }
