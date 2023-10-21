{ label-studio, ... }:

final: prev:

{
  label_studio = label-studio.packages.${prev.system}.label-studio;
}
