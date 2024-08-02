{ nixpkgs-python, nixpkgs, pyarrow, ... }:

final: prev: {
  nix-python = nixpkgs-python.packages.${prev.system};
  arrow-cpp_11 = pyarrow.packages.${prev.system}.arrow-cpp;
}

