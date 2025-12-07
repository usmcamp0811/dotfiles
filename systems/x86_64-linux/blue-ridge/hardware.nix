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
  # Note: availableKernelModules is set below with LUKS config
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # Bootloader configuration - using systemd-boot for UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # LUKS configuration for encrypted /persist with USB keyfile
  # The system will look for the key on a USB drive at boot
  boot.initrd.luks.devices."crypted-persist" = {
    device = "/dev/disk/by-partlabel/disk-main-persist";
    # Key file path on USB drive - adjust the UUID to match your USB device
    # Find USB UUID with: lsblk -f or blkid
    # Example paths:
    # - keyFile = "/dev/disk/by-uuid/XXXX-XXXX/persist.key";
    # - keyFile = "/dev/disk/by-label/USBKEY/persist.key";
    keyFile = "/dev/disk/by-label/USBKEY/persist.key";
    keyFileSize = 4096;  # 4KB key size
    allowDiscards = true;
    fallbackToPassword = true;  # Allow password entry if USB is not found
  };

  # Ensure USB storage modules are available in initrd
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "uas"];

  # Impermanence: Root is ephemeral tmpfs, wiped on boot
  # Only /nix and /persist survive reboots
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # NOTE: /boot and /nix are managed by disko, but we keep these for reference
  # disko.nix will generate the actual mount configuration
  # If these conflict, you can comment them out and rely solely on disko

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/disk-main-ESP";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-partlabel/disk-main-nix";
    fsType = "ext4";
    neededForBoot = true;
    options = [ "noatime" ];
  };

  # Encrypted persist partition - mounted via LUKS mapper
  fileSystems."/persist" = {
    device = "/dev/mapper/crypted-persist";
    fsType = "ext4";
    neededForBoot = true;
    options = [ "noatime" ];
  };

  # Swap is handled by disko with randomEncryption
  # No need to explicitly define swapDevices here
  swapDevices = [];

  # Rollback root to blank state on boot
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir -p /mnt
    # We don't need to wipe anything since root is tmpfs
    # But we ensure /persist exists
    mount -t ext4 /dev/mapper/crypted-persist /mnt
    mkdir -p /mnt/system
    umount /mnt
  '';

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
