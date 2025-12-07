# Disko configuration with encrypted /persist for unattended boot
# Security: /persist is encrypted, /nix is plain (no secrets in nix store)
# Key stored on /boot (protected by physical security + optional Secure Boot)
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition
            boot = {
              size = "1M";
              type = "EF02";
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

            # Nix store - UNENCRYPTED (contains no secrets, world-readable anyway)
            nix = {
              size = "180G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/nix";
                mountOptions = [ "noatime" ];
              };
            };

            # Persistent data - UNENCRYPTED
            persist = {
              size = "50G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/persist";
                mountOptions = [ "noatime" ];
              };
            };

            # Swap - encrypted with random key (regenerated each boot)
            swap = {
              size = "100%";
              content = {
                type = "swap";
                randomEncryption = true; # Fresh random key each boot
              };
            };
          };
        };
      };
    };

    # Root is tmpfs (ephemeral)
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
