{ lib, config, ... }:

with lib;
let
  cfg = config.campground.services.hadoop;
in
{
  options.campground.services.hadoop = with types; {
    enable = mkBoolOpt false "Enable Hadoop services.";

    hostname = mkOption {
      description = "Hostname for the Hadoop services (e.g., for the NameNode, ResourceManager).";
      default = "localhost";
      type = types.str;
    };

    role = mkOption {
      description = "Role of the Hadoop node. Can be 'namenode', 'datanode', 'resourcemanager', 'nodemanager', or 'master-worker'.";
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
      description = lib.mdDoc "Hadoop core-site.xml definition.";
      default = {
        "fs.defaultFS" = "hdfs://${cfg.hostname}";
      };
      type = types.attrsOf anything;
      example = {
        "fs.defaultFS" = "hdfs://${cfg.hostname}";
      };
    };

    hdfsSite = mkOption {
      description = lib.mdDoc "Hadoop hdfs-site.xml definition.";
      default = {
        "dfs.replication" = "1";
        "dfs.namenode.name.dir" = "/var/lib/hadoop/hdfs/namenode";
        "dfs.datanode.data.dir" = "/var/lib/hadoop/hdfs/datanode";
      };
      type = types.attrsOf anything;
    };

    yarnSite = mkOption {
      description = lib.mdDoc "Hadoop yarn-site.xml definition.";
      default = {
        "yarn.resourcemanager.hostname" = cfg.hostname;
        "yarn.nodemanager.aux-services" = "mapreduce_shuffle";
      };
      type = types.attrsOf anything;
    };

    mapredSite = mkOption {
      description = lib.mdDoc "Hadoop mapred-site.xml definition.";
      default = {
        "mapreduce.framework.name" = "yarn";
      };
      type = types.attrsOf anything;
    };

    logging = mkOption {
      description = lib.mdDoc "Hadoop logging configuration.";
      default = ''
        log4j.rootLogger=INFO, console
        log4j.appender.console=org.apache.log4j.ConsoleAppender
        log4j.appender.console.target=System.err
        log4j.appender.console.layout=org.apache.log4j.PatternLayout
        log4j.appender.console.layout.ConversionPattern=%d{ISO8601} %-5p %c{2} - %m%n
      '';
      type = types.lines;
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/hadoop";
      description = lib.mdDoc "Data directory for Hadoop.";
    };

    extraFlags = mkOption {
      description = lib.mdDoc "Additional flags for Hadoop services.";
      default = "";
      type = types.str;
    };

    extraEnv = mkOption {
      description = lib.mdDoc "Additional environment variables for Hadoop services.";
      default = "";
      type = types.attrsOf types.str;
    };
  };

  config = mkIf cfg.enable {
    services.hadoop = {
      coreSite = cfg.coreSite;
      hdfsSite = cfg.hdfsSite;
      yarnSite = cfg.yarnSite;
      mapredSite = cfg.mapredSite;
      logging = cfg.logging;
      dataDir = cfg.dataDir;
      extraFlags = cfg.extraFlags;
      extraEnv = cfg.extraEnv;
      enable = true;

      # Role-based configuration
      hdfs = {
        namenode.enable = cfg.role == "namenode" || cfg.role == "master-worker";
        datanode.enable = cfg.role == "datanode" || cfg.role == "master-worker";
      };
      yarn = {
        resourcemanager.enable = cfg.role == "resourcemanager" || cfg.role == "master-worker";
        nodemanager.enable = cfg.role == "nodemanager" || cfg.role == "master-worker";
      };
    };
  };
}
