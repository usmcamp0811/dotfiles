{ gradle2nix, ... }:

final: prev:

{
  gradle2nix = gradle2nix.packages.${prev.system}.gradle2nix;
}
