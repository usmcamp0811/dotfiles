{ unstable, ... }:

final: prev:

{

  mesa = unstable.legacyPackages.${prev.system}.mesa;
}
