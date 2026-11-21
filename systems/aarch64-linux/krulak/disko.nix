{
  disko.devices = {
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = ["size=2G" "mode=755"];
    };
    disk.main = {
      type = "disk";
      # Deliberately not a real device. Replace only after verifying the target disk.
      device = "/dev/disk/by-id/REPLACE-WITH-YOUR-NVME-ID";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              # No key file: Disko prompts for a passphrase.
              content = {
                type = "btrfs";
                subvolumes = builtins.listToAttrs (map (path: {
                  name = path;
                  value = {
                    mountpoint = path;
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                }) ["/home" "/nix" "/persist"]);
              };
            };
          };
        };
      };
    };
  };
}
