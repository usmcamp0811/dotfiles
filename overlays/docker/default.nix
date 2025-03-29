{ compose2nix, nix2container, ... }:
final: prev: {
  compose2nix = compose2nix.packages.${prev.system}.default;
  nix2containerPkgs = nix2container.packages.${prev.system};
}
