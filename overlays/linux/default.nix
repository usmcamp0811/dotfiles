{ unstable, channels, ... }:

final: prev:

{

  inherit (channels.unstable) linuxPackages_latest;
  # hardware.nvidia.package = channels.unstable.linuxPackages_latest.nvidia_x11;
  # hardware.opengl.package = channels.unstable.mesa_drivers;
  # Fixes an issue with building Raspberry Pi kernels:
  # https://github.com/NixOS/nixpkgs/issues/154163
  # linuxPackages_latest = unstable.legacyPackages.${prev.system}.linuxPackages_latest;
  # nvidia_x11 = unstable.legacyPackages.${prev.system}.linuxPackages_latest.nvidia_x11;
      # linux = unstable.linux_latest;
      # nvidia_x11 = unstable.nvidia_x11_latest;
  # makeModulesClosure = x: prev.makeModulesClosure (x // {
  #   allowMissing = true;
  # });
}

