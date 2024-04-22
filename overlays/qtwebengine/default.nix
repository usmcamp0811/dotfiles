{ nixpkgs, ... }:
final: prev: {
  qtwebengine = nixpkgs.legacyPackages.${prev.system}.qtwebengine;
}
