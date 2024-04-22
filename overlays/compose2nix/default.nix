{ compose2nix, ... }:
final: prev: {
  compose2nix = compose2nix.packages.${prev.system}.default;
}
