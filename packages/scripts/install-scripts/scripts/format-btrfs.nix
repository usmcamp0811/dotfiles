{ pkgs }:
pkgs.writeShellScriptBin "format-btrfs" ''
  # Default install drive
  install_drive=${"1:-/dev/nvme0n1"}

  # Function to display help menu
  show_help() {
    echo "Usage: format-btrfs [OPTIONS] [DRIVE]"
    echo ""
    echo "Format a drive with LUKS encryption and Btrfs filesystem."
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help       Show this help menu."
    echo ""
    echo "DRIVE:"
    echo "  The drive to format (e.g., /dev/sdX or /dev/nvme0n1)."
    echo "  If not provided, defaults to /dev/nvme0n1."
    exit 0
  }

  # Check for help option
  case "$1" in
    -h|--help)
      show_help
      ;;
  esac

  # Partition layout assumptions
  boot_partition="''${install_drive}p1"
  luks_partition="''${install_drive}p2"

  # LUKS encryption
  echo "Formatting ''${luks_partition} with LUKS encryption..."
  sudo ${pkgs.cryptsetup}/bin/cryptsetup --batch-mode -c aes-xts-plain64 --use-random luksFormat "$luks_partition"
  sudo ${pkgs.cryptsetup}/bin/cryptsetup luksOpen "$luks_partition" luks

  # Format as Btrfs
  echo "Formatting /dev/mapper/luks as Btrfs..."
  sudo ${pkgs.btrfs-progs}/bin/mkfs.btrfs /dev/mapper/luks

  # Create subvolumes
  echo "Setting up Btrfs subvolumes..."
  sudo mkdir -p /mnt
  sudo mount /dev/mapper/luks /mnt
  sudo ${pkgs.btrfs-progs}/bin/btrfs subvolume create /mnt/root
  sudo ${pkgs.btrfs-progs}/bin/btrfs subvolume create /mnt/home
  sudo ${pkgs.btrfs-progs}/bin/btrfs subvolume create /mnt/persist
  sudo umount /mnt

  # Mount subvolumes
  echo "Mounting Btrfs subvolumes..."
  sudo mount -o subvol=root,compress=lzo /dev/mapper/luks /mnt
  sudo mkdir -p /mnt/{boot,home,persist}
  sudo mount -o subvol=home,compress=lzo /dev/mapper/luks /mnt/home
  sudo mount -o subvol=persist,compress=lzo /dev/mapper/luks /mnt/persist

  # Mount boot partition
  echo "Mounting boot partition..."
  sudo mount "$boot_partition" /mnt/boot

  echo "Drive formatted and mounted successfully!"
''
