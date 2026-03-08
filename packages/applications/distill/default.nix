{ lib, pkgs, ... }:
pkgs.writeShellApplication {
  name = "distill";
  runtimeInputs = [ pkgs.nodejs pkgs.steam-run ];
  text = ''
    exec steam-run npx --yes @samuelfaj/distill "$@"
  '';

  meta = with lib; {
    description = "Distill large CLI outputs for LLM workflows";
    homepage = "https://github.com/samuelfaj/distill";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "distill";
  };
}
