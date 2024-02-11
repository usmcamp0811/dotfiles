{ channels, unstable, ... }:

final: prev:

{

  # python311Packages = unstable.legacyPackages.${prev.system}.python311Packages;

  inherit (channels.unstable) python311Packages;
}
