{ channels, unstable, nixpkgs, ... }:

final: prev:
{
  gcc-unstable = unstable.legacyPackages.${prev.system}.gcc;
}                                                                                   
                                                                                   
