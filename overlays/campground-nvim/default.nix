{ campground-nvim, ... }:

final: prev:

{
  neovim = campground-nvim.packages.${prev.system}.default;
}

