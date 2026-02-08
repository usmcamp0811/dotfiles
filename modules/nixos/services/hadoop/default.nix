{ lib, config, ... }:
with lib;
with lib.fmf;
# If this is the first time or you still don't know what to do with Hadoop 
# I had to do `sudo hdfs namenode -format` to format the storage
let cfg = config.fmf.services.hadoop;
in {
  options.fmf.services.hadoop = with types; {
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
      default = {
        # Specify the default filesystem
        "fs.defaultFS" = "hdfs://campground";

        # Configuration for HA and failover
        "ha.zookeeper.quorum" =
          "webb:2181,chesty:2181,reckless:2181,lucas:2181";

        # Retry settings (optional but recommended for robustness)
        "ipc.client.connect.max.retries" = "10";
        "ipc.client.connect.retry.interval" = "1000"; # in milliseconds

        # Temp directory
        "hadoop.tmp.dir" = "/var/lib/hadoop/tmp";
      };
      type = types.attrsOf anything;
    };

    hdfsSite = mkOption {
      description = lib.mdDoc "Hadoop hdfs-site.xml configuration.";
      default = {

      };
      type = types.attrsOf anything;
    };

    yarnSite = mkOption {
      description = lib.mdDoc "Hadoop yarn-site.xml configuration.";
      default = {

      };
      type = types.attrsOf anything;
    };

    mapredSite = mkOption {
      description = lib.mdDoc "Hadoop mapred-site.xml configuration.";
      default = {

      };
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
        httpfs.tempPath = "/var/lib/hadoop/httpfs";
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
    systemd.tmpfiles.rules = [
      "d /var/lib/hadoop 2775 hdfs hadoop - -"
      "d /var/lib/hadoop/tmp 2775 hdfs hadoop - -"
      "d /var/lib/hadoop/httpfs 2775 hdfs hadoop - -"
      "d /var/lib/hadoop/dfs 2775 hdfs hadoop - -"
      "d /var/lib/hadoop/dfs/name 2700 hdfs hadoop - -"
      "d /var/lib/hadoop/dfs/data 2775 hdfs hadoop - -"
      "d /var/lib/hadoop/dfs/edits 2775 hdfs hadoop - -"
    ];
    services.hadoop = {
      coreSite = cfg.coreSite;
      hdfsSite = cfg.hdfsSite;

      hdfsSiteDefault = {
        # "dfs.namenode.http-address" = "0.0.0.0:9870";
        "dfs.namenode.http-bind-host" = "0.0.0.0";
        "dfs.namenode.rpc-bind-host" = "0.0.0.0";
        "dfs.namenode.servicerpc-bind-host" = "0.0.0.0";
        # Basic HDFS settings
        "dfs.replication" = "2";

        # HA configuration
        "dfs.nameservices" = "campground";
        "dfs.ha.namenodes.campground" = "nn1,nn2";

        # RPC addresses for each NameNode in HA setup
        "dfs.namenode.rpc-address.fmf.nn1" = "lucas:8020";
        "dfs.namenode.rpc-address.fmf.nn2" = "chesty:8020";

        # HTTP addresses for each NameNode (for web UI, optional)
        "dfs.namenode.http-address.fmf.nn1" = "lucas:50070";
        "dfs.namenode.http-address.fmf.nn2" = "chesty:50070";

        # JournalNode settings (optional, but recommended in an HA setup)
        "dfs.namenode.shared.edits.dir" =
          "qjournal://webb:8485;reckless:8485;lucas:8485/campground";
        "dfs.namenode.name.dir" = "/var/lib/hadoop/dfs/name";
        "dfs.datanode.data.dir" = "/var/lib/hadoop/dfs/data";
        "dfs.journalnode.edits.dir" = "/var/lib/hadoop/dfs/edits";
        # Automatic failover configurations (optional)
        "dfs.client.failover.proxy.provider.campground" =
          "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider";
      };
      yarnSite = cfg.yarnSite;
      yarnSiteDefault = {
        "yarn.nodemanager.admin-env" = "PATH=$PATH";
        "yarn.nodemanager.aux-services.mapreduce_shuffle.class" =
          "org.apache.hadoop.mapred.ShuffleHandler";
        "yarn.nodemanager.bind-host" = "0.0.0.0";
        "yarn.nodemanager.container-executor.class" =
          "org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor";
        "yarn.nodemanager.env-whitelist" =
          "JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,LANG,TZ";
        "yarn.nodemanager.linux-container-executor.group" = "hadoop";
        "yarn.nodemanager.linux-container-executor.path" =
          "/run/wrappers/yarn-nodemanager/bin/container-executor";
        "yarn.nodemanager.log-dirs" = "/var/log/hadoop/yarn/nodemanager";
        "yarn.resourcemanager.bind-host" = "0.0.0.0";

        # General YARN settings
        "yarn.resourcemanager.ha.enabled" = "true";
        "yarn.resourcemanager.cluster-id" = "campground";
        # ResourceManager HA configuration
        "yarn.resourcemanager.ha.rm-ids" = "rm1,rm2";

        # Hostnames of the ResourceManagers
        "yarn.resourcemanager.hostname.rm1" = "daly";
        "yarn.resourcemanager.hostname.rm2" = "webb";

        # RPC addresses for ResourceManagers
        "yarn.resourcemanager.address.rm1" = "daly:8032";
        "yarn.resourcemanager.address.rm2" = "webb:8032";

        # Web UI addresses for ResourceManagers (optional)
        "yarn.resourcemanager.webapp.address.rm1" = "daly:8088";
        "yarn.resourcemanager.webapp.address.rm2" = "webb:8088";

        # Automatic failover configurations
        "yarn.resourcemanager.zk-address" = "webb:2181,chesty:2181,daly:2181";
        "yarn.resourcemanager.ha.automatic-failover.enabled" = "true";
        "yarn.resourcemanager.ha.automatic-failover.zk-base-path" =
          "/yarn-leader-election";

        # NodeManager configuration (assuming NodeManagers are running on all nodes)
        "yarn.nodemanager.aux-services" = "mapreduce_shuffle";
        "yarn.nodemanager.aux-services.mapreduce.shuffle.class" =
          "org.apache.hadoop.mapred.ShuffleHandler";

        # Application Master configuration
        "yarn.resourcemanager.scheduler.class" =
          "org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler";
      };
      mapredSite = cfg.mapredSite;
      mapredSiteDefault = {
        "yarn.app.mapreduce.am.env" =
          "HADOOP_MAPRED_HOME=${config.services.hadoop.package}";
        "mapreduce.map.env" =
          "HADOOP_MAPRED_HOME=${config.services.hadoop.package}";
        "mapreduce.reduce.env" =
          "HADOOP_MAPRED_HOME=${config.services.hadoop.package}";

        # Specify the framework for MapReduce
        "mapreduce.framework.name" = "yarn";

        # Enable job history server (optional, but recommended)
        "mapreduce.jobhistory.address" = "daly:10020";
        "mapreduce.jobhistory.webapp.address" = "daly:19888";

        # Use the YARN ResourceManager logical name
        "yarn.resourcemanager.ha.enabled" = "true";
        "yarn.resourcemanager.cluster-id" = "campground";
        "yarn.resourcemanager.ha.rm-ids" = "rm1,rm2";

        # ResourceManager address (no need to specify individual RM addresses, as it's handled by YARN)
        "mapreduce.jobtracker.address" = "campground";

        # Shuffle service configuration
        "mapreduce.job.reduce.slowstart.completedmaps" = "0.05";

        # Retrying on connection failures (optional, but recommended)
        "mapreduce.client.submit.file.replication" = "10";

        # (Optional) History server configurations
        "mapreduce.jobhistory.intermediate-done-dir" =
          "/tmp/hadoop-yarn/staging/history/done_intermediate";
        "mapreduce.jobhistory.done-dir" =
          "/tmp/hadoop-yarn/staging/history/done";
      };
      log4jProperties = cfg.log4jProperties;

      hdfs = cfg.hdfs;

      yarn = cfg.yarn;

      extraConfDirs = cfg.extraConfDirs;
    };
  };
}
