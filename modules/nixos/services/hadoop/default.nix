{ lib, config, ... }:
with lib;
with lib.campground;

let cfg = config.campground.services.hadoop;
in {
  options.campground.services.hadoop = with types; {
    enable = mkBoolOpt false "Enable Hadoop services.";

    role = mkOption {
      description = lib.mdDoc "The role of the node in the Hadoop cluster.";
      default = "master-worker";
      type = types.enum [
        "namenode"
        "datanode"
        "resourcemanager"
        "nodemanager"
        "master-worker"
      ];
    };

    coreSite = mkOption {
      description = lib.mdDoc "Hadoop core-site.xml configuration.";
      default = { "fs.defaultFS" = "hdfs://${config.networking.hostName}"; };
      type = types.attrsOf anything;
    };

    hdfsSite = mkOption {
      description = lib.mdDoc "Hadoop hdfs-site.xml configuration.";
      default = { "dfs.replication" = "3"; };
      type = types.attrsOf anything;
    };

    yarnSite = mkOption {
      description = lib.mdDoc "Hadoop yarn-site.xml configuration.";
      default = {
        "yarn.resourcemanager.hostname" = "${config.networking.hostName}";
      };
      type = types.attrsOf anything;
    };

    mapredSite = mkOption {
      description = lib.mdDoc "Hadoop mapred-site.xml configuration.";
      default = { };
      type = types.attrsOf anything;
    };

    log4jProperties = mkOption {
      description =
        lib.mdDoc "Path to Hadoop log4j.properties configuration file.";
      default = "${config.services.hadoop.package}/etc/hadoop/log4j.properties";
      type = types.path;
    };

    extraConfDirs = mkOption {
      description = lib.mdDoc "Extra configuration directories for Hadoop.";
      default = [ ];
      type = types.listOf types.path;
    };

    hdfs = mkOption {
      type = types.attrsOf types.anything;
      default = {
        namenode.enable = cfg.role == "namenode" || cfg.role == "master-worker";
        namenode.restartIfChanged = false;
        namenode.openFirewall = false;
        namenode.extraFlags = [ ];
        namenode.extraEnv = { };

        datanode.enable = cfg.role == "datanode" || cfg.role == "master-worker";
        datanode.restartIfChanged = false;
        datanode.openFirewall = true;
        datanode.extraFlags = [ ];
        datanode.extraEnv = { };
        datanode.dataDirs = [ ];

        journalnode.enable = false;
        journalnode.restartIfChanged = false;
        journalnode.openFirewall = true;
        journalnode.extraFlags = [ ];
        journalnode.extraEnv = { };

        zkfc.enable = false;
        zkfc.restartIfChanged = false;
        zkfc.extraFlags = [ ];
        zkfc.extraEnv = { };

        httpfs.enable = false;
        httpfs.tempPath = "/tmp/hadoop/httpfs";
        httpfs.restartIfChanged = false;
        httpfs.openFirewall = false;
        httpfs.extraFlags = [ ];
        httpfs.extraEnv = { };
      };
      description =
        "Configuration for Hadoop HDFS service, including NameNode, DataNode, JournalNode, ZKFC, and HTTPFS options.";
    };

    yarn = mkOption {
      type = types.attrsOf types.anything;
      default = {
        resourcemanager.enable = cfg.role == "resourcemanager" || cfg.role
          == "master-worker";
        resourcemanager.restartIfChanged = false;
        resourcemanager.openFirewall = false;
        resourcemanager.extraFlags = [ ];
        resourcemanager.extraEnv = { };

        nodemanager.enable = cfg.role == "nodemanager" || cfg.role
          == "master-worker";
        nodemanager.useCGroups = true;
        nodemanager.restartIfChanged = false;
        nodemanager.resource.memoryMB = null;
        nodemanager.resource.maximumAllocationVCores = null;
        nodemanager.resource.maximumAllocationMB = null;
        nodemanager.resource.cpuVCores = null;
        nodemanager.openFirewall = false;
        nodemanager.localDir = null;
        nodemanager.extraFlags = [ ];
        nodemanager.extraEnv = { };
        nodemanager.addBinBash = true;
      };
      description =
        "Configuration for Hadoop YARN service, including ResourceManager and NodeManager options.";
    };
  };

  config = mkIf cfg.enable {
    services.hadoop = {
      coreSite = cfg.coreSite;
      hdfsSite = cfg.hdfsSite;
      yarnSite = cfg.yarnSite;
      mapredSite = cfg.mapredSite;
      log4jProperties = cfg.log4jProperties;

      hdfs = cfg.hdfs;

      yarn = cfg.yarn;

      extraConfDirs = cfg.extraConfDirs;
    };
  };
}
