{lib, ...}:
with lib;
with lib.fmf; {
  imports = [./hardware.nix];

  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  fmf = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel" "docker"];
      uid = 10000;
    };
    archetypes = {
      workstation = enabled;
      server = {
        enable = true;
        hostId = "930864f0";
      };
    };
    desktop.addons.rkvm = {
      # enableServer = true;
      enableClient = true;
      address = "reckless:5258";
    };
    suites = {
      # kubernetes = {
      #   enable = true;
      #   role = "controller";
      #   interface = "eno1";
      #   isLeader = true;
      # };
      public-hosting = {
        enable = true;
        interface = "eno1";
        log-to-kafka = true;
      };
      # kafka = {
      #   enable = true;
      #   ui-server = true;
      #   ui-bootstrap-server = "lucas:9092";
      #   zookeeper-id = 4;
      #   connect-server = true;
      #   schema-server = true;
      #   servers = ''
      #     server.1=chesty:2888:3888
      #     server.2=webb:2888:3888
      #     server.3=daly:2888:3888
      #     server.4=0.0.0.0:2888:3888
      #   '';
      # };
    };
    nfs.client.enable = true;
    # tools.attic = enabled;

    hardware = {nvidia = enabled;};
    services = {
      glusterfs = {
        enable = true;
        peers = ["reckless"];
        volumes = [
          {
            name = "kubernetes";
            brickDirs = ["/glusterfs/kubernetes"];
            replicaCount = 2;
            transport = "tcp";
          }
        ];
      };
      netbird.client.enable = true;
      k3s = {
        modules = {
          certificates = enabled;
          traefik = enabled;
          external-secrets = enabled;
          argocd = enabled;
        };
        # enable = true;
        role = "server";
        clusterInit = true;
        extraFlags = [
          "--tls-san 10.8.0.197"
        ];
      };

      vault = {
        enable = true;
        ui = true;
        auto-unseal = true;
        storage = {
          backend = "raft";
          path = "/persist/vault-raft";
          config = ''
            node_id = "vault-node-lucas"
            retry_join {
              leader_api_addr = "https://chesty:8200"
            }
            retry_join {
              leader_api_addr = "https://ermy:8200"
            }
            retry_join {
              leader_api_addr = "https://daly:8200"
            }
            retry_join {
              leader_api_addr = "https://webb:8200"
            }
          '';
        };
        settings = ''
          cluster_addr = "http://lucas:8201"
          api_addr = "http://lucas:8200"
        '';

        policies =
          builtins.foldl'
          (policies: file:
            policies
            // {
              "${snowfall.path.get-file-name-without-extension file}" = file;
            })
          {}
          (builtins.filter (snowfall.path.has-file-extension "hcl")
            (builtins.map
              (path:
                ../daly/vault/policies
                + "/${
                  builtins.baseNameOf (builtins.unsafeDiscardStringContext path)
                }")
              (snowfall.fs.get-files ../daly/vault/policies)));
      };
      n8n = {enable = true;};
      chromadb = {enable = true;};
      # onlyoffice = { enable = true; };
      ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
      };
      # hadoop = {
      #   enable = true;
      #   yarnSite = { "yarn.nodemanager.hostname" = "lucas"; };
      #   hdfs = {
      #     namenode.enable = true;
      #     namenode.restartIfChanged = true;
      #     namenode.openFirewall = true;
      #     namenode.extraFlags = [ ];
      #     namenode.extraEnv = { };
      #
      #     datanode.enable = true;
      #     datanode.restartIfChanged = true;
      #     datanode.openFirewall = true;
      #     datanode.extraFlags = [ ];
      #     datanode.extraEnv = { };
      #     datanode.dataDirs = [ ];
      #
      #     journalnode.enable = true;
      #     journalnode.restartIfChanged = true;
      #     journalnode.openFirewall = true;
      #     journalnode.extraFlags = [ ];
      #     journalnode.extraEnv = { };
      #
      #     httpfs.enable = true;
      #     httpfs.tempPath = "/var/lib/hadoop/httpfs";
      #   };
      #   yarn = {
      #     nodemanager.enable = true;
      #     nodemanager.useCGroups = false;
      #     nodemanager.restartIfChanged = true;
      #     nodemanager.resource.memoryMB = null;
      #     nodemanager.resource.maximumAllocationVCores = null;
      #     nodemanager.resource.maximumAllocationMB = null;
      #     nodemanager.resource.cpuVCores = null;
      #     nodemanager.openFirewall = true;
      #     nodemanager.localDir = null;
      #     nodemanager.extraFlags = [ ];
      #     nodemanager.extraEnv = { };
      #     nodemanager.addBinBash = true;
      #   };
      # };
      # flink-task-manager = {
      #   enable = true;
      #   flink-conf = ''
      #     jobmanager.rpc.address: lucas
      #     jobmanager.rpc.port: 6123
      #     jobmanager.memory.process.size: 1600m
      #     taskmanager.memory.process.size: 1728m
      #     taskmanager.numberOfTaskSlots: 20
      #     parallelism.default: 1
      #     jobmanager.execution.failover-strategy: region
      #     blob.server.port: 6124
      #     query.server.port: 6125
      #   '';
      # };
      # example-flink-job = { enable = true; };
      # matt-camp-website = enabled;
      nix-slide-website = enabled;
      # attic-watch-store = enabled;
      gitlab-runner = enabled;
      campground-blog = enabled;
      searx = {
        enable = true;
        port = 3249;
      };
      zfs-key-server = {
        enable = true;
        port = 8123;
        interface = "eno1";
        tang-servers = [
          "http://pikvm:1234"
          # "http://daly:1234"
          # "http://mattis:1234"
          # "http://chesty:1234"
          # "http://ermy:1234"
          # # "http://webb:1234"
          # "http://reckless:1234"
        ];
      };
      user-secrets = {
        enable = true;
        users.mcamp = {files = ["id_ed25519" "passwords"];};
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            # address = "http://lucas:8200";
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/lucas/role-id";
            secret-id = "/var/lib/vault/lucas/secret-id";
          };
        };
      };
    };
  };

  system.stateVersion = "23.05";
}
