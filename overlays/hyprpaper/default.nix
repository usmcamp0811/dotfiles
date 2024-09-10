{ hyprpaper, hyprland-works-here, ... }:
final: prev: {
  hyprpaper = hyprpaper.packages.${prev.system}.default;
  hyprland = hyprland-works-here.legacyPackages.x86_64-linux.hyprland;
}
