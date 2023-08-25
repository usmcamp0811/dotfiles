{ campground-nvim, ... }:

final: prev:

{
  nvim = campground-nvim.packages.${prev.system}.default;
  # inherit (campground-nvim.packages.${prev.system}) nvim;
}

