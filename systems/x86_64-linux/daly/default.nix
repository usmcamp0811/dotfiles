{ lib, ... }:
with lib;
with lib.campground; {
  imports = [ ./hardware.nix ];
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" ];
      uid = 10000;
    };
    suites = {
      desktop.enable = mkForce false;
      lan-hosting = {
        enable = true;
        interface = "enp3s0f1";
      };
      # kubernetes = {
      #   enable = true;
      #   role = "controller";
      #   interface = "enp3s0f1";
      #   isLeader = true;
      # };

      # kafka = {
      #   enable = true;
      #   interface = "enp3s0f1";
      #   zookeeper-id = 3;
      #   ui-server = true;
      #   servers = ''
      #     server.1=chesty:2888:3888
      #     server.2=webb:2888:3888
      #     server.3=0.0.0.0:2888:3888
      #     server.4=lucas:2888:3888
      #   '';
      # };
    };
    archetypes = {
      laptop = enabled;
      server = {
        enable = true;
        hostId = "65c8b2d7";
      };
    };
    # security = {
    #   acme = enabled;
    # };
    nfs.client = { enable = true; };

    services = {
      k3s = {
        enable = true;
        role = "server";
        serverAddr = "https://10.8.0.197:6443";
        extraFlags = [
          "--tls-san 10.8.0.197"
        ];
      };
      # lemmy = enabled;
      # lynis = enabled;
      # netbird.server = enabled;
      ldap-client = { enable = mkForce false; };
      authentik = { enable = true; };
      borgbackup = {
        enable = true;
        jobs = {
          "daly_campground" = {
            paths = [ "/persist" ];
            repo = "mcamp@reckless:/mnt/backups/daly";
            startAt = "daily";
          };
          "daly_rsync" = {
            paths = [ "/persist" ];
            repo = "de3288@de3288.rsync.net:/data2/home/de3288/backups/daly";
            startAt = "daily";
          };
        };
      };
      searx = {
        enable = true;
        port = 8181;
      };
      campground-blog = enabled;
      matt-camp-website = enabled;

      hadoop = {
        # enable = true;
        yarnSite = {
          "yarn.nodemanager.hostname" = "daly";
          "yarn.scheduler.capacity.root.queues" = "default";
          "yarn.scheduler.capacity.root.default.capacity" = "100";
        };
        hdfs = {
          datanode.enable = true;
          datanode.restartIfChanged = true;
          datanode.openFirewall = true;
          datanode.extraFlags = [ ];
          datanode.extraEnv = { };
          datanode.dataDirs = [ ];

          journalnode.enable = true;
          journalnode.restartIfChanged = true;
          journalnode.openFirewall = true;
          journalnode.extraFlags = [ ];
          journalnode.extraEnv = { };
        };
        yarn = {
          resourcemanager.enable = true;
          resourcemanager.openFirewall = true;
          resourcemanager.restartIfChanged = true;
          resourcemanager.extraFlags = [ ];
          resourcemanager.extraEnv = { };

          nodemanager.enable = true;
          nodemanager.useCGroups = false;
          nodemanager.restartIfChanged = true;
          nodemanager.resource.memoryMB = null;
          nodemanager.resource.maximumAllocationVCores = null;
          nodemanager.resource.maximumAllocationMB = null;
          nodemanager.resource.cpuVCores = null;
          nodemanager.openFirewall = true;
          nodemanager.localDir = null;
          nodemanager.extraFlags = [ ];
          nodemanager.extraEnv = { };
          nodemanager.addBinBash = true;
        };
      };
      zfs-key-server = {
        enable = true;
        interface = "enp3s0f1";
        tang-servers = [
          "http://webb:1234"
          "http://chesty:1234"
          # "http://lucas:1234"
          "http://ermy:1234"
          "http://reckless:1234"
        ];
        port = 8123;
      };
      user-secrets = {
        enable = true;
        users = { mcamp = { files = [ "id_ed25519" "passwords" ]; }; };
      };
      # wireguard = {
      #   enable = true;
      #   port = 1149;
      #   nic = "enp3s0f1";
      #   interface-name = "campnet";
      #   ips = [ "10.100.0.10/24" ];
      #   peers = [
      #     {
      #       # butler
      #       publicKey = "Thdtm9iUmcZFgFMiJUm0T0EaBe/gvfmcBHrSi5Gvfm8=";
      #       presharedKeyFile = "/var/lib/wireguard/campnet/preshared-key";
      #       allowedIPs = [ "10.100.0.2/32" ];
      #     }
      #     {
      #       # phone
      #       publicKey = "cq5+lO9tjEom1pUuXtb9rfAfSN6DZxDZkKWdVQ6Cokw=";
      #       presharedKeyFile = "/var/lib/wireguard/campnet/preshared-key";
      #       allowedIPs = [ "10.100.0.3/32" ];
      #     }
      #   ];
      # };
      vault = {
        enable = true;
        ui = true;
        auto-unseal = true;
        storage = {
          backend = "raft";
          config = ''
            node_id = "vault-node-daly"
            retry_join {
              leader_api_addr = "http://chesty:8200"
            }
            retry_join {
              leader_api_addr = "http://ermy:8200"
            }
            retry_join {
              leader_api_addr = "http://webb:8200"
            }
            retry_join {
              leader_api_addr = "http://lucas:8200"
            }
          '';
        };
        settings = ''
          cluster_addr = "http://daly:8201"
          api_addr = "http://daly:8200"
        '';

        policies =
          builtins.foldl'
            (policies: file:
              policies
              // {
                "${snowfall.path.get-file-name-without-extension file}" = file;
              })
            { }
            (builtins.filter (snowfall.path.has-file-extension "hcl")
              (builtins.map
                (path:
                  ./vault/policies
                  + "/${
                  builtins.baseNameOf (builtins.unsafeDiscardStringContext path)
                }")
                (snowfall.fs.get-files ./vault/policies)));
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            # address = "http://lucas:8200";
            role-id = "/var/lib/vault/daly/role-id";
            secret-id = "/var/lib/vault/daly/secret-id";
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
