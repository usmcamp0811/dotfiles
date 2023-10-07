{
  disko.devices = {
    disk = {
      nvme0n1 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1G"; # Adjust size as needed
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
                pool = "NIXROOT";
                options = {
                  mountpoint = "none";
                  encryption = "aes-256-gcm";
                  keyformat = "passphrase";
                  keylocation = "prompt";
                };
              };
            };
          };
        };
      };
    };
    zpool = {
      NIXROOT = {
        type = "zpool";
        mode = "single";
        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "none";
        postCreateHook = "zfs snapshot NIXROOT@blank";

        datasets = {
          root = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
          };
          home = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
          };
          persist = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
          };
          reserved = {
            type = "zfs_fs";
            options = {
              refreservation = "1G";
              mountpoint = "none";
            };
          };
        };
      };
    };
  };
}
