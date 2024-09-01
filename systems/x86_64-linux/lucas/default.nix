{ lib, ... }:
with lib;
with lib.campground; {
  imports = [ ./hardware.nix ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" ];
      uid = 10000;
    };
    archetypes = {
      workstation = enabled;
      server = {
        enable = true;
        k8s = true;
        role = "worker";
        hostId = "930864f0";
      };
    };
    desktop.addons.rkvm = {
      # enableServer = true;
      enableClient = true;
      address = "reckless:5258";
    };
    suites = {
      public-hosting = {
        enable = true;
        interface = "eno1";
        log-to-kafka = true;
      };
      kafka = {
        enable = true;
        ui-server = true;
        ui-bootstrap-server = "lucas:9092";
        zookeeper-id = 4;
        connect-server = true;
        schema-server = true;
        servers = ''
          server.1=chesty:2888:3888
          server.2=webb:2888:3888
          server.3=daly:2888:3888
          server.4=0.0.0.0:2888:3888
        '';
      };
    };
    nfs.client.enable = true;
    tools.attic = enabled;

    hardware = { nvidia = enabled; };
    services = {
      onlyoffice = { enable = true; };
      nix-ai = enabled;

      firefly = enabled;

      hadoop = {
        enable = true;
        role = "master-worker";
        coreSite = {
          "fs.defaultFS" = "hdfs://reckless:8020";
          "yarn.scheduler.capacity.root.queues" = "default";
          "yarn.scheduler.capacity.root.default.capacity" = 100;
        };
        yarnSite = {
          "yarn.nodemanager.hostname" = "reckless";
          "yarn.resourcemanager.hostname" = "reckless";
          "yarn.nodemanager.aux-services" = "mapreduce_shuffle";
          "yarn.acl.enable" = 0;
        };
        mapredSite = { "mapreduce.framework.name" = "yarn"; };
        hdfsSite = { "dfs.replication" = "1"; };
        hdfs = {
          namenode.enable = true;
          namenode.restartIfChanged = true;
          namenode.openFirewall = true;
          namenode.extraFlags = [ ];
          namenode.extraEnv = { };

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

          zkfc.enable = true;
          zkfc.restartIfChanged = true;
          zkfc.extraFlags = [ ];
          zkfc.extraEnv = { };

          httpfs.enable = true;
          httpfs.tempPath = "/tmp/hadoop/httpfs";
          httpfs.restartIfChanged = true;
          httpfs.openFirewall = true;
          httpfs.extraFlags = [ ];
          httpfs.extraEnv = { };
        };
        yarn = {

          resourcemanager.enable = true;
          resourcemanager.restartIfChanged = true;
          resourcemanager.openFirewall = true;
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
      matt-camp-website = enabled;
      attic-watch-store = enabled;
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
          # "http://daly:1234"
          # "http://mattis:1234"
          "http://chesty:1234"
          # "http://ermy:1234"
          "http://webb:1234"
          "http://reckless:1234"
        ];
      };
      user-secrets = {
        enable = true;
        users.mcamp = { files = [ "id_ed25519" "passwords" ]; };
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
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
