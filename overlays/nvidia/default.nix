{ unstable, ... }:

final: prev:

{

  inherit (channels.unstable) linuxPackages_latest;
  inherit (channels.unstable) linuxKernel;
  # nvidia_x11 = unstable.legacyPackages.${prev.system}.nvidia_x11;
  # nvidia_x11 = unstable.legacyPackages.${prev.system}.nvidia_x11;
}
