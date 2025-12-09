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

  # LUKS configuration for encrypted /persist with USB keyfile
  # The system will look for the key on a USB drive at boot
  boot.initrd.luks.devices."crypted-persist" = {
    device = "/dev/disk/by-partlabel/disk-main-persist";
    # Key file will be mounted from USB drive in preLuksCommands below
    keyFile = "/tmp/usbkey/persist.key";
    keyFileSize = 4096;  # 4KB key size
    allowDiscards = true;
    fallbackToPassword = true;  # Allow password entry if USB is not found
  };

  # Mount USB key before LUKS unlock
  boot.initrd.preLuksCommands = ''
    echo "Looking for USB keyfile..."
    mkdir -p /tmp/usbkey

    # Wait for USB device to appear (max 10 seconds)
    for i in $(seq 1 10); do
      if [ -e /dev/disk/by-uuid/cea8f5b6-d40e-4043-b23d-c6326dab421b ]; then
        echo "USB key found, mounting..."
        mount -t ext4 /dev/disk/by-uuid/cea8f5b6-d40e-4043-b23d-c6326dab421b /tmp/usbkey
        if [ -f /tmp/usbkey/persist.key ]; then
          echo "Keyfile found on USB!"
          break
        else
          echo "ERROR: persist.key not found on USB"
          umount /tmp/usbkey
        fi
      fi
      echo "Waiting for USB key... ($i/10)"
      sleep 1
    done
  '';

  # Unmount USB key after LUKS unlock
  boot.initrd.postMountCommands = ''
    if mountpoint -q /tmp/usbkey; then
      echo "Unmounting USB keyfile..."
      umount /tmp/usbkey
    fi
  '';

  # Ensure USB storage modules are available in initrd
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "uas"];

  # Ensure ext4 module is loaded for USB key filesystem
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
