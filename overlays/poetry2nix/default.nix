{ poetry2nix, ... }:

final: prev:

{
  poetry2nix = poetry2nix.packages.${prev.system}.default;
}

