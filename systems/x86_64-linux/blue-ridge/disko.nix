{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition for legacy boot compatibility
            boot = {
              size = "1M";
              type = "EF02"; # BIOS boot
            };

            # EFI System Partition
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            # Nix store partition - most of the disk space
            nix = {
              size = "180G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/nix";
                mountOptions = [ "noatime" ];
              };
            };

            # Persistent data partition
            persist = {
              size = "50G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/persist";
                mountOptions = [ "noatime" ];
              };
            };

            # Swap partition
            swap = {
              size = "100%"; # Use remaining space (should be ~7.5G)
              content = {
                type = "swap";
                resumeDevice = true; # Enable hibernation support
              };
            };
          };
        };
      };
    };

    # Root is tmpfs (ephemeral) - not on disk
    # This is handled in hardware.nix with fileSystems."/"
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "defaults"
          "size=2G"
          "mode=755"
        ];
      };
    };
  };
}
