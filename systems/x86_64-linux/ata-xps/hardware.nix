{ config, lib, pkgs, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/135e05a9-e446-47e1-a25a-5157f74db1bf";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."luks-2166fd6f-7c05-4980-b094-a410d4555054".device = "/dev/disk/by-uuid/2166fd6f-7c05-4980-b094-a410d4555054";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/5516-4405";
      fsType = "vfat";
    };

  # NFS Mounts
  fileSystems."/mnt/campfs" = {
    device = "campfs.campground.lan:/mnt/campfs";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot.initrd.extraUtilsCommands = ''
    # clevis dependencies
    copy_bin_and_libs ${pkgs.curl}/bin/curl
    copy_bin_and_libs ${pkgs.bash}/bin/bash
    copy_bin_and_libs ${pkgs.jose}/bin/jose

    # clevis scripts and binaries
    for i in ${pkgs.clevis}/bin/* ${pkgs.clevis}/bin/.clevis-wrapped; do
      copy_bin_and_libs "$i"
    done
  '';

  boot.initrd.luks.devices.nixos-root = {
    device = "/dev/disk/by-uuid/2166fd6f-7c05-4980-b094-a410d4555054";
    preOpenCommands = with pkgs; ''
      ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-${bash.name}
      ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-${clevis.name}
      ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-${coreutils.name}

      bash -e -c 'while [ ! -f /crypt-ramfs/device ]; do sleep 1; done; . /bin/clevis-luks-common-functions; clevis_luks_unlock_device "$(cat /crypt-ramfs/device)" | cryptsetup-askpass' &
    '';
  };
}

