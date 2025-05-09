{ lib
, pkgs
,
}:
# adapted from https://github.com/charles-bord/nix-forest-slides/tree/master
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "slidev";
  version = "0.49.29";
  src = pkgs.fetchFromGitHub {
    owner = "slidevjs";
    repo = "slidev";
    rev = "v${finalAttrs.version}";
    hash = "sha256-bOSIJTzPMyS+wbJsLVaMw/wicbsgQADEOyQQjU8MKWw=";
  };

  nativeBuildInputs = [ pkgs.nodejs pkgs.pnpm_9.configHook pkgs.makeWrapper ];

  pnpmDeps = pkgs.pnpm_9.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-18/6hNsRq0hl1UXY6cchuIEVWTbCiZJG33QHDvnXS1A=";
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

    makeWrapper "${pkgs.nodejs}/bin/node" "$out/bin/slidev" \
      --set NODE_PATH "$out/node_modules" \
      --add-flags "$out/packages/slidev/bin/slidev.mjs"

    runHook postInstall
  '';

  meta = {
    description = "Presentation Slides for Developers";
    homepage = "https://sli.dev/";
    changelog = "https://github.com/slidevjs/slidev/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "slidev";
    maintainers = with lib.maintainers; [ ];
  };
})
