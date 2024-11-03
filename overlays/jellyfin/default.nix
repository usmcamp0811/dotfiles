{ nix-ai, ... }:
final: prev: {
  jellyfin = unstable.outputs.packages.${prev.system}.jellyfin;
}
