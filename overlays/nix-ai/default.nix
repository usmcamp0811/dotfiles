{ nix-ai, ... }:
final: prev: {
  textgen-nvidia = nix-ai.outputs.packages.${prev.system}.textgen-nvidia;
  textgen-amd = nix-ai.outputs.packages.${prev.system}.textgen-amd;
}
