{
  disko.devices = {
    disk = {
      nvme0n1 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      zroot = {
        type = "zpool";
        mode = ""; # You can change this to "mirror" if you have another disk
        rootFsOptions = {
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/";
        postCreateHook = "zfs snapshot zroot@blank";

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "/";
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "file:///tmp/secret.key";
            };
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
          };
          persist = {
            type = "zfs_fs";
            mountpoint = "/persist";
          };
          encrypted = {type = "zfs_fs";};
        };
      };
    };
  };
}
# sudo nix run github:nix-community/disko -- --mode disko ./disko.nix --arg disks '[ "/dev/nvme0n1" ]'

