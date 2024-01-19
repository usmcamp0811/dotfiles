{ nixpkgs, ... }:

final: prev:

{

  webkitgtk = nixpkgs.legacyPackages.${prev.system}.webkitgtk;
}
