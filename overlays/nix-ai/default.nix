{ nix-ai, ... }:
final: prev: {
  textgen-nvidia = nix-ai.outputs.packages.${prev.system}.textgen-nvidia;
}
