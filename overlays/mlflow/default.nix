{ unstable, ... }:

final: prev:

{

  python311Packages = unstable.legacyPackages.${prev.system}.python311Packages;
}
