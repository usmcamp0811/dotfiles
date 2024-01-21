{ pkgs, lib, inputs,... }:

with lib;
with lib.campground;
let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };

in
{
  imports = [ 
    ./hardware.nix
  ];

  campground = {
    user = {
      name = "abe";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel"];
    };

    archetypes = {
      workstation = enabled;
      server = {
        enable = true;
        hostId = "13ec383b";
      };
    };

    suites = {
      development = enabled;
    };

    nix = {
      extra-substituters = {
         "https://nix-gaming.cachix.org"  = {
          key = "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=";
        };
      };
    };

    apps = {
      steam = enabled;
    };

    nfs.client = {
      enable = true;
    };

    hardware = {
      ckb-next = enabled;
      nvidia = enabled;
    };

    services = {
      attic = {
        enable = true; 
        settings = {
          database = {
            url = "postgres://atticd@localhost/atticd?host=/run/postgresql/";
          };
          storage = {
            type = "local";
            path = "/var/lib/atticd";
          };
          chunking = {
            "nar-size-threshold" = 65536; # chunk files that are 64 KiB or larger
            "min-size" = 16384;           # 16 KiB
            "avg-size" = 65536;           # 64 KiB
            "max-size" = 262144;          # 256 KiB
          };
          compression = {
            type = "zstd";
          };
          garbage-collection = {
            interval = "12 hours";
          };
        };
      };

      postgresql = {
        enable = true;
        enableTCPIP = true;
        backupEnable = true;
        backupLocation = "/persist/postgresqlBackups/";
        authentication = ''
          local all root trust
          local all postgres peer
          local atticd atticd trust
          host  all  all  0.0.0.0/0  reject
          host  all  all  ::0/0  reject
        '';
      };
      nix-snapshotter = enabled;
      zfs-key-server = {
        enable = false;
        tang-servers = [
         "http://webb:1234" 
         "http://lucas:1234" 
         "http://ermy:1234" 
        ];
      };

      user-secrets = {
        enable = true;
        users = {
          mcamp =  {
            files = [
              "id_ed25519"
              "passwords"
              "kubeconfig"
            ];
          };
        };
      };

      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/reckless/role-id";
            secret-id = "/var/lib/vault/reckless/secret-id";
          };
        };
      };
    };
  };


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}

