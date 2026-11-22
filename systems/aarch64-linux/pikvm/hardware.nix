{
  inputs,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # SD card layout: root on NIXOS_SD, firmware on FIRMWARE, extlinux via U-Boot. It also makes the image a
    # build output: nix build .#nixosConfigurations.pikvm.config.system.build.sdImage
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
    # Pi 4 device trees, overlays and firmware. Its kernel is a default (mkDefault) and is replaced below.
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # The kernel nvmd/nixos-raspberrypi builds and caches for the Pi 4 (the same package set as its
  # `raspberry-pi-4.base` module), taken from the flake input as-is. Do NOT add `follows` to that input and do
  # not override the kernel: either changes the derivation, the cache then has no matching output, and the
  # kernel compiles from source (hours on a Pi, long on a builder).
  boot.kernelPackages = inputs.nixos-raspberrypi.packages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_rpi4;

  # The generic SD-image profile adds initrd drivers for other ARM boards (for example Rockchip `dw-hdmi`)
  # that the Raspberry Pi kernel does not ship, which fails the initrd build ("Module dw-hdmi not found").
  # Keep the Pi 4 module's drivers and the explicit USB drivers below.
  hardware.enableAllHardware = lib.mkForce false;
  hardware.enableRedistributableFirmware = true;

  boot.initrd.availableKernelModules = ["usbhid" "usb_storage"];
}
