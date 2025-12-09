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

  # LUKS configuration for encrypted /persist with USB keyfile
  boot.initrd.luks.devices."crypted-persist" = {
    device = "/dev/disk/by-partlabel/disk-main-persist";
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

  # Ensure USB and ext4 modules are available in initrd
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "uas"];
  boot.initrd.kernelModules = ["ext4"];

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
