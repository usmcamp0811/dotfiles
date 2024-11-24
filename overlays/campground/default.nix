{ campground-nvim, old-nixpkgs, ... }:
final: prev: {
  campground-nvim = campground-nvim.packages.${prev.system}.nvim;
  neovide = old-nixpkgs.legacyPackages.${prev.system}.neovide;
}
