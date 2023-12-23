{ nix-snapshotter, ... }:

final: prev:

{
  nix-snapshotter = nix-snapshotter.packages.${prev.system}.nix-snapshotter;
}

