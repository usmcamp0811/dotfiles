{ sbomnix, ... }:

final: prev:

{
  sbomnix = nix2sbom.packages.${prev.system}.default;
}

