{ flake, ... }:

final: prev:

{
  flake = flake.overlay;
}

