{ inputs, ... }:
final: prev: {
  scientific-fhs = inputs.scientific-fhs.packages.x86_64-linux.scientific-fhs;
}
