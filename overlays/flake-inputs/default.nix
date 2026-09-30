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
}: final: prev: let
  system = prev.stdenv.hostPlatform.system;
in {
  # Hyprland ecosystem
  hyprpaper = hyprpaper.packages.${system}.default;

  # Security & SBOM tools
  sbomnix = sbomnix.packages.${system}.default;
  nix2sbom = nix2sbom.packages.${system}.default;

  # AI/ML tools
  textgen-nvidia = nix-ai.outputs.packages.${system}.textgen-nvidia;
  textgen-amd = nix-ai.outputs.packages.${system}.textgen-amd;

  # Nix utilities
  output-monitor = nix-output-monitor.packages.${system}.default;
  nix-snapshotter = nix-snapshotter.packages.${system}.nix-snapshotter;

  # Container tools
  compose2nix = compose2nix.packages.${system}.default;
  nix2containerPkgs = nix2container.packages.${system};
  # streamLayeredImageConf comes from flakeforge overlay applied in flake.nix

  # Development environments
  scientific-fhs = inputs.scientific-fhs.packages.${system}.scientific-fhs;

  # Backlog.md - A tool for managing project collaboration between humans and AI Agents in a git ecosystem
  backlog-md = inputs.backlog.packages.${system}.backlog-md;

  # ai-jail - OS sandbox (bubblewrap + Landlock + seccomp) for AI coding agents.
  # The flake's package is already wrapped with BWRAP_BIN pointing at a store bwrap.
  # doCheck is off because upstream's test suite includes a Landlock test
  # (apply_net_rules_v4_unavailable_hard_fails_with_documented_wording) whose
  # result depends on the build host's kernel Landlock ABI, and it fails in
  # our build sandbox (763 pass, 1 fails).
  ai-jail = inputs.ai-jail.packages.${system}.default.overrideAttrs (_: {
    doCheck = false;
  });
}
