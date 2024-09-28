{ campground-nvim, ... }:
final: prev: {
  campground-nvim = campground-nvim.packages.${prev.system}.nvim;
}
