{ unstable, channels, ... }:

final: prev:

{

  inherit (channels.unstable) nvidia_x11;
  # hardware.nvidia.package = channels.unstable.linuxPackages_latest.nvidia_x11;
  # hardware.opengl.package = channels.unstable.mesa_drivers;
}

