{ nix2sbom, ... }:
final: prev: {
  nix2sbom = nix2sbom.packages.${prev.system}.default;
}
