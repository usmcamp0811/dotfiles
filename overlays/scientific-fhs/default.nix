{ scientific-fhs, ... }:

final: prev:

{
  julia = scientific-fhs.packages.${prev.system}.julia;
}

