{ nix2sbom, ... }:

final: prev:
{
  inherit (nix2sbom.packages.${prev.system}) nix2sbom;
}
