{ scientific-fhs, ... }:

final: prev:

{
  scientific-fhs = scientific-fhs.packages.${prev.system}.default;
}
