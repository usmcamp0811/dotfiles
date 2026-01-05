# Packages sourced from flake inputs
# These are external flakes that provide packages we want to use
{
  hyprpaper,
  sbomnix,
  nix-ai,
  nix-output-monitor,
  nix-snapshotter,
  nix2sbom,
  flakeforge,
  compose2nix,
  nix2container,
  inputs,
  ...
}:
final: prev: {
  # Hyprland ecosystem
  hyprpaper = hyprpaper.packages.${prev.system}.default;

  # Security & SBOM tools
  sbomnix = sbomnix.packages.${prev.system}.default;
  nix2sbom = nix2sbom.packages.${prev.system}.default;

  # AI/ML tools
  textgen-nvidia = nix-ai.outputs.packages.${prev.system}.textgen-nvidia;
  textgen-amd = nix-ai.outputs.packages.${prev.system}.textgen-amd;

  # Nix utilities
  output-monitor = nix-output-monitor.packages.${prev.system}.default;
  nix-snapshotter = nix-snapshotter.packages.${prev.system}.nix-snapshotter;

  # Container tools
  compose2nix = compose2nix.packages.${prev.system}.default;
  nix2containerPkgs = nix2container.packages.${prev.system};
  streamLayeredImageConf = flakeforge.packages.${prev.system}.flakeforgeTools.streamLayeredImageConf;

  # Development environments
  scientific-fhs = inputs.scientific-fhs.packages.${prev.system}.scientific-fhs;
}
