{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  # newUser = name: {
  #   isNormalUser = true;
  #   createHome = true;
  #   home = "/home/${name}";
  #   shell = pkgs.zsh;
  # };
  # findEnabledServices = { serviceName }: builtins.filter (name: let
  #   cfg = self.nixosConfigurations.${name}.config.services.${serviceName}.enable;
  #   in cfg) (builtins.attrNames self.nixosConfigurations);
  # searxEnabledSystems = findEnabledServices { serviceName = "searx"; };
  # searxURLs = map (host: {
  #   # You need to obtain the port for each service dynamically if it varies; otherwise, specify it directly if constant
  #   url = "http://${host}:${cfg.port}"; # Replace PORT with the actual port or a method to retrieve it dynamically
  # }) searxEnabledSystems;
in {
  imports = [./hardware.nix];

  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel" "docker"];
      uid = 10000;
    };
    suites = {
      public-hosting = {
        enable = true;
        interface = "eno1";
        log-to-kafka = true;
      };
      # kubernetes = {
      #   enable = true;
      #   role = "worker";
      #   interface = "eno1";
      # };
      observability = {
        enable = true;
        loki = true;
        prometheus = true;
      };
      # kafka = {
      #   enable = true;
      #   connect-server = true;
      #   timescale-server = true;
      #   schema-server = true;
      #   zookeeper-id = 2;
      #   servers = ''
      #     server.1=chesty:2888:3888
      #     server.2=0.0.0.0:2888:3888
      #     server.3=daly:2888:3888
      #     server.4=lucas:2888:3888
      #   '';
      # };
    };

    archetypes = {
      server = {
        enable = true;
        hostId = "119db424";
      };
    };

    tools = {attic = enabled;};

    services = {
      gitlab = {
        enable = true;
      };
      glusterfs = {
        enable = true;
        peers = ["reckless" "lucas"];
        volumes = [
          {
            name = "kubernetes";
            brickDirs = ["/glusterfs/kubernetes"];
            replicaCount = 2;
            transport = "tcp";
          }
        ];
      };
      k3s = {
        enable = true;
        role = "agent";
        serverAddr = "10.8.0.197";
      };
      # onlyoffice = { enable = true; };
      pds = enabled;
      lemmy = enabled;
      matt-camp-website = enabled;
      netbird.server = enabled;
      vault = {
        enable = true;
        ui = true;
        auto-unseal = true;
        snapshot = {enable = true;};
        storage = {
          backend = "raft";
          config = ''
            node_id = "vault-node-webb"
            retry_join {
              leader_api_addr = "http://chesty:8200"
            }
            retry_join {
              leader_api_addr = "http://ermy:8200"
            }
            retry_join {
              leader_api_addr = "http://daly:8200"
            }
          '';
        };
        settings = ''
          cluster_addr = "http://webb:8201"
          api_addr = "http://webb:8200"
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
                ./vault/policies
                + "/${
                  builtins.baseNameOf (builtins.unsafeDiscardStringContext path)
                }")
              (snowfall.fs.get-files ./vault/policies)));
      };
      remark42 = {
        enable = true;
        port = 11842;
      };
      # hadoop = {
      #   enable = true;
      #   yarnSite = { "yarn.nodemanager.hostname" = "webb"; };
      #   hdfs = {
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
      #   };
      #   yarn = {
      #     resourcemanager.enable = true;
      #     resourcemanager.restartIfChanged = false;
      #     resourcemanager.openFirewall = true;
      #     resourcemanager.extraFlags = [ ];
      #     resourcemanager.extraEnv = { };
      #
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
      firefly = enabled;
      firefly-plaid-connector = enabled;
      campground-blog = enabled;
      nextcloud = {enable = true;};
      ldap-client = {enable = mkForce false;};
      uptime-kuma = enabled;
      grafana = {
        enable = true;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://webb:9011";
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://webb:3030";
          }
          {
            name = "Firefly Postgres";
            type = "postgres";
            access = "proxy"; # Grafana handles the queries via the proxy
            host = "/run/postgresql";
            user = "firefly"; # The correct user
            database = "firefly"; # The firefly database
            jsonData.sslmode = "disable";
          }
        ];
      };
      # collabora = enabled;
      attic-watch-store = enabled;
      nixery = enabled;
      docker = enabled;
      minio = enabled;
      mlflow = enabled;
      # airflow = enabled;
      # label-studio = enabled;
      vaultwarden = enabled;
      mattermost = enabled;
      paperless = enabled;
      # crowdsec = enabled;

      mysql = {
        backupEnable = true;
        backupLocation = "/persist/mysqlBackups/";
      };

      immich = {
        enable = true;
        mediaLocation = "/webb/media/photos";
      };
      # spark = {
      #   enable = true;
      #   port = 8081;
      #   worker = {
      #     master = "spark://reckless:7077";
      #     workDir = "/var/lib/spark";
      #     enable = true;
      #     extraEnvironment = {
      #       SPARK_WORKER_CORES = "4";
      #       SPARK_WORKER_MEMORY = "4g";
      #     };
      #     restartIfChanged = true;
      #   };
      #   logDir = "/var/log/spark";
      # };

      borgbackup = {
        enable = true;
        jobs = {
          "webb_campground" = {
            paths = [
              "/persist"
              "/webb/media/photos"
              "/webb/media/immich"
              "/webb/kubernetes"
              "/webb/backups/openwrt-backups"
              "/var/lib/paperless"
              "/var/lib/minio"
              "/var/lib/label-studio"
              "/var/lib/mattermost/files"
              "/var/lib/remark42/"
            ];
            repo = "mcamp@reckless:/mnt/backups/webb";
            startAt = "daily";
          };
          "webb_rsync" = {
            extraArgs = ["--remote-path=borg14"];
            paths = [
              "/persist"
              "/webb/media/photos"
              "/webb/media/immich"
              "/webb/kubernetes"
              "/webb/backups/openwrt-backups"
              "/var/lib/paperless"
              "/var/lib/minio"
              "/var/lib/label-studio"
              "/var/lib/mattermost/files"
              "/var/lib/remark42/"
            ];
            repo = "de3288@de3288.rsync.net:/data2/home/de3288/backups/webb";
            startAt = "daily";
          };
        };
      };
      postgresql = {
        enable = true;
        enableTCPIP = true;
        backupEnable = true;
        backupLocation = "/persist/postgresqlBackups/";
        databases = [
          {
            name = "campgroundai";
            user = "campgroundai";
          }
        ];
        authentication = [
          "local   all        root      trust" # Allow trusted local connections for root
          "local   all        postgres  peer" # Use peer authentication for postgres user locally

          "local   immich    immich   trust" # Allow trusted local connections for immich user to immich DB
          "local   firefly    firefly   trust" # Allow trusted local connections for firefly user to firefly DB
          "host    firefly    firefly   127.0.0.1/32 trust" # Allow trusted connections from localhost (IPv4) for firefly user to firefly DB
          "host    firefly    firefly   ::1/128 trust" # Allow trusted connections from localhost (IPv6) for firefly user to firefly DB
          "host    firefly    firefly   0.0.0.0/0 md5"

          "host  campgroundai  campgroundai  0.0.0.0/0 md5"

          "host    all        all       0.0.0.0/0 reject" # Reject all other IPv4 connections
          "host    all        all       ::/0 reject" # Reject all other IPv6 connections
        ];
      };
      matomo = enabled;

      zfs-key-server = {
        enable = true;
        port = 8123;
        tang-servers = [
          "http://pikvm:1234"
          # "http://daly:1234"
          # # "http://lucas:1234"
          # "http://reckless:1234"
          # "http://chesty:1234"
          # "http://ermy:1234"
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
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/webb/role-id";
            secret-id = "/var/lib/vault/webb/secret-id";
          };
        };
      };
    };
    nfs.client = enabled;
  };

  system.stateVersion = "23.05";
}
