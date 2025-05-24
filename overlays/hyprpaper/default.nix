{ hyprpaper, ... }: final: prev: {
  hyprpaper = hyprpaper.packages.${prev.system}.default;
}
