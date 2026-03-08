{ lib, pkgs, ... }:
let
  version = "0.1.31";

  distillBinary = pkgs.stdenvNoCC.mkDerivation {
    pname = "distill-linux-x64";
    inherit version;

    src = pkgs.fetchurl {
      url =
        "https://registry.npmjs.org/@samuelfaj/distill-linux-x64/-/distill-linux-x64-${version}.tgz";
      hash = "sha256-FdLu2eO9ElV2hJtP8MSJwPXHdNupFCrW4VldIhfpsp8=";
    };

    sourceRoot = "package";
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 bin/distill "$out/libexec/distill"
      runHook postInstall
    '';
  };
in pkgs.writeShellApplication {
  name = "distill";
  runtimeInputs = [ pkgs.steam-run ];
  text = ''
    exec steam-run ${distillBinary}/libexec/distill "$@"
  '';

  meta = with lib; {
    description = "Distill large CLI outputs for LLM workflows";
    homepage = "https://github.com/samuelfaj/distill";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "distill";
  };
}
