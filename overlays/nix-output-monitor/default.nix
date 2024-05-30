{ nix-output-monitor, ... }:
final: prev: {
  output-monitor = nix-output-monitor.packages.${prev.system}.default;
}
