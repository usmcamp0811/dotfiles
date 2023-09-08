{ technofab, ... }:

final: prev:

{
  k0s = technofab.packages.${prev.system}.k0s;
}

