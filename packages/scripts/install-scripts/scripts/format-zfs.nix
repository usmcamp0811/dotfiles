{ pkgs }:
pkgs.writeShellScriptBin "format-zfs" ''
  # Default install drive
  install_drive=${"1:-/dev/nvme0n1"}

  # Function to display help menu
  show_help() {
    echo "Usage: format-zfs [OPTIONS] [DRIVE]"
    echo ""
    echo "Format a drive with ZFS and set up ZFS datasets."
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

  # Partition variables
  boot_partition="''${install_drive}p1"
  zfs_partition="''${install_drive}p2"

  # Export any active pools
  echo "Exporting active ZFS pools..."
  sudo ${pkgs.zfs}/bin/zpool export -a

  # Import existing pools
  echo "Importing existing ZFS pools..."
  sudo ${pkgs.zfs}/bin/zpool import || true

  # Create ZFS pool
  echo "Creating ZFS pool on ''${zfs_partition}..."
  sudo ${pkgs.zfs}/bin/zpool create -f \
    -o altroot="/mnt" \
    -o ashift=12 \
    -o autotrim=on \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O normalization=formD \
    -O dnodesize=auto \
    -O sync=disabled \
    -O encryption=aes-256-gcm \
    -O keylocation=prompt \
    -O keyformat=passphrase \
    -O mountpoint=none \
    NIXROOT \
    "$zfs_partition"

  # Create ZFS datasets
  echo "Creating ZFS datasets..."
  sudo ${pkgs.zfs}/bin/zfs create -o mountpoint=legacy NIXROOT/root
  sudo ${pkgs.zfs}/bin/zfs create -o mountpoint=legacy NIXROOT/home
  sudo ${pkgs.zfs}/bin/zfs create -o mountpoint=legacy NIXROOT/persist

  # Reserve space
  echo "Creating reserved dataset..."
  sudo ${pkgs.zfs}/bin/zfs create -o refreservation=1G -o mountpoint=none NIXROOT/reserved

  # Mount root dataset
  echo "Mounting root dataset..."
  sudo mkdir -p /mnt
  sudo mount -t zfs NIXROOT/root /mnt

  # Set up directory structure
  echo "Creating directory structure..."
  sudo mkdir -p /mnt/{boot,home,persist}

  # Mount boot partition
  echo "Mounting boot partition..."
  sudo mount "$boot_partition" /mnt/boot

  # Mount other datasets
  echo "Mounting ZFS datasets..."
  sudo mount -t zfs NIXROOT/home /mnt/home
  sudo mount -t zfs NIXROOT/persist /mnt/persist

  echo "ZFS setup completed successfully!"
''
