{ pkgs }:
pkgs.writeShellScriptBin "partition" ''
  # Default install drive and boot partition size
  install_drive=${"1:-/dev/nvme0n1"}
  boot_size=${"2:-1G"}

  # Function to display help menu
  show_help() {
    echo "Usage: partition [OPTIONS] [DRIVE] [BOOT_SIZE]"
    echo ""
    echo "Partition a drive for installation."
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help       Show this help menu."
    echo ""
    echo "DRIVE:"
    echo "  The drive to partition (e.g., /dev/sdX or /dev/nvme0n1)."
    echo "  If not provided, defaults to /dev/nvme0n1."
    echo ""
    echo "BOOT_SIZE:"
    echo "  Size of the boot partition (e.g., 512M, 1G)."
    echo "  If not provided, defaults to 1G."
    exit 0
  }

  # Check for help option
  case "$1" in
    -h|--help)
      show_help
      ;;
  esac

  # Zap the NVMe drive
  sudo ${pkgs.gptfdisk}/bin/sgdisk --zap-all "$install_drive"

  # Create a boot partition with specified size
  sudo ${pkgs.gptfdisk}/bin/sgdisk -n 1:0:+$boot_size -t 1:EF00 "$install_drive"

  # Create a partition for the remaining space
  sudo ${pkgs.gptfdisk}/bin/sgdisk -n 2:0:0 -t 2:BF00 "$install_drive"

  # Make sure Boot is bootable
  sudo ${pkgs.parted}/bin/parted $install_drive -- set 1 esp on
''
