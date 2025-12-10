# Full disk encryption with USB keyfile + passphrase fallback
# Uses systemd stage 1 initrd for USB key handling
# Security: Entire disk encrypted except ESP (required for UEFI boot)
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition (for legacy boot compatibility)
            boot = {
              size = "1M";
              type = "EF02";
            };

            # EFI System Partition (must be unencrypted for UEFI boot)
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

            # Everything else encrypted with LUKS
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                # Prompt for passphrase during installation
                # After disko completes, add USB key with:
                # cryptsetup luksAddKey /dev/disk/by-partlabel/disk-main-luks /mnt/usbkey/persist.key
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    # Nix store
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };

                    # Persistent data (system state, user data)
                    "/persist" = {
                      mountpoint = "/persist";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };

                    # Swap
                    "/swap" = {
                      mountpoint = "/.swapvol";
                      swap.swapfile.size = "20G";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

    # Root is tmpfs (ephemeral, wiped on boot)
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
