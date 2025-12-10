# Intel N100 4-LAN Router Hardware Configuration
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Intel N100 (Alder Lake-N) CPU
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # Bootloader configuration - using systemd-boot for UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable systemd in initrd for better USB device handling
  boot.initrd.systemd.enable = true;

  # LUKS configuration for full disk encryption with USB keyfile
  boot.initrd.luks.devices."crypted" = {
    device = "/dev/disk/by-partlabel/disk-main-luks";
    keyFile = "/usbkey/persist.key";
    keyFileSize = 4096;  # 4KB key size
    allowDiscards = true;
    # fallbackToPassword is automatic with systemd stage 1
  };

  # Mount USB key in initrd using systemd fstab
  boot.initrd.systemd.contents."/etc/fstab".text = ''
    UUID=cea8f5b6-d40e-4043-b23d-c6326dab421b /usbkey ext4 ro 0 0
  '';

  # Create the mountpoint directory in initrd
  boot.initrd.systemd.emergencyAccess = true;  # Allow shell access if something fails

  # Ensure USB and filesystem modules are available in initrd
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "uas"];
  boot.initrd.kernelModules = ["ext4" "btrfs"];

  # Impermanence: Root is ephemeral tmpfs, wiped on boot
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # Boot partition (unencrypted ESP)
  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/disk-main-ESP";
    fsType = "vfat";
    options = ["umask=0077"];
  };

  # Nix store - btrfs subvolume inside LUKS
  fileSystems."/nix" = {
    device = "/dev/mapper/crypted";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
    neededForBoot = true;
  };

  # Persistent data - btrfs subvolume inside LUKS
  fileSystems."/persist" = {
    device = "/dev/mapper/crypted";
    fsType = "btrfs";
    options = ["subvol=persist" "compress=zstd" "noatime"];
    neededForBoot = true;
  };

  # Swap via btrfs swapfile
  swapDevices = [{
    device = "/.swapvol/swapfile";
  }];


  # Intel N100 specific optimizations
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Enable firmware for network cards
  hardware.enableRedistributableFirmware = true;

  # Power management for efficiency
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # Network interface naming - Intel I226-V NICs
  # The N100 4-LAN typically has 4x Intel I226-V 2.5GbE NICs
  # Using predictable interface names
  boot.kernelParams = [
    "net.ifnames=1"
  ];

  # System architecture
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
