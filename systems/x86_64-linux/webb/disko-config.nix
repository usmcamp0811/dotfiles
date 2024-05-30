{
  disko.devices = {
    disk = {
      sda = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "NIXROOT";
              };
            };
          };
        };
      };
      sdb = {
        type = "disk";
        device = "/dev/sdb";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "NIXROOT";
              };
            };
          };
        };
      };
      sdc = {
        type = "disk";
        device = "/dev/sdc";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "NIXROOT";
              };
            };
          };
        };
      };
      sdd = {
        type = "disk";
        device = "/dev/sdd";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "NIXROOT";
              };
            };
          };
        };
      };
      sde = {
        type = "disk";
        device = "/dev/sde";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "NIXROOT";
              };
            };
          };
        };
      };
      sdf = {
        type = "disk";
        device = "/dev/sdf";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "NIXROOT";
              };
            };
          };
        };
      };
      sdg = {
        type = "disk";
        device = "/dev/sdg";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "NIXROOT";
              };
            };
          };
        };
      };
      sdh = {
        type = "disk";
        device = "/dev/sdh";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "NIXROOT";
              };
            };
          };
        };
      };
      sdi = {
        type = "disk";
        device = "/dev/sdi";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "28G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
          };
        };
      };
    };
    zpool = {
      NIXROOT = {
        type = "zpool";
        mode = ""; # You can change this to "mirror" if you have another disk
        rootFsOptions = {
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/";
        postCreateHook = "zfs snapshot NIXROOT@blank";

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
            options = {
              mountpoint = "/";
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "file:///tmp/secret.key";
            };
          };
          persist = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options = {
              mountpoint = "/";
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "file:///tmp/secret.key";
            };
          };

          reserved = {
            type = "zfs_fs";
            options = {
              mountpoint = "";
              refreservation = "1G";
            };
          };
        };
      };
    };
  };
}
# sudo nix run github:nix-community/disko -- --mode disko ./disko.nix --arg disks '[ "/dev/nvme0n1" ]'

