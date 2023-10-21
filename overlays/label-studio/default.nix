{ campground-packages, ... }:

final: prev:

{
  label_studio = campground-packages.packages.${prev.system}.label-studio;
}
