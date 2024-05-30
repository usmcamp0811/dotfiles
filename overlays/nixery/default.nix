{ nixery-flake, nixpkgs, ... }:
final: prev: {
  nixery-pkgs = import nixery-flake.outPath {
    pkgs = import nixpkgs { system = "${prev.system}"; };
  };
}
