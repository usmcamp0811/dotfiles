{ nix-snapshotter, ... }:

final: prev:

{
  nix-snapshotter = nix-snapshotter.overlays.default;
}

