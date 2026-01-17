{
  lib,
  pkgs,
  namespace ? "campground",
  ...
}:
let
  # Reference to the flake source
  flakeSrc = ../..;
in
# Convenience wrapper for blue-ridge disko
pkgs.writeShellApplication {
  name = "disko-blue-ridge";
  runtimeInputs = with pkgs; [nix];
  text = ''
    # Run the main disko package with blue-ridge argument
    # The flake source path is embedded in the disko package itself
    exec nix run ${flakeSrc}#disko -- blue-ridge "$@"
  '';
}
