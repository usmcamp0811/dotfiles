{ nixpkgs-python, nixpkgs, ... }:

final: prev: {
  nix-python = nixpkgs-python.packages.${prev.system};
}

