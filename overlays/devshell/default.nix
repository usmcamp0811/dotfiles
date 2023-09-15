{ devshell, ... }:

final: prev:

{
  devshell = devshell.packages.${prev.system}.default;
}

