{ nixpkgs, ... }:
final: prev: {
  qemu = nixpkgs.legacyPackages.${prev.system}.qemu;
}
