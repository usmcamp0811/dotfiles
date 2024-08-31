{ config, pkgs, lib, ... }:

let
  cfg = config.campground.services.hadoop;
  # Define the available roles
  roles = [ "leader" "worker" "both" ];
in {
  options.campground.services.hadoop = {
    type = lib.types.enum roles;
    default = "both";
    description = ''
      Define the role of the Hadoop service. 
      Possible values: "leader" (NameNode + ResourceManager), 
                       "worker" (DataNode + NodeManager), 
                       "both" (All services).
    '';
  };

  config = mkIf cfg.enable {
    services.hadoop = {
      enable = true;

      coreSite = {
        "fs.defaultFS" = "hdfs://localhost:9000";
        "hadoop.tmp.dir" = "/var/hadoop/tmp";
      };

      hdfsSite = {
        "dfs.replication" = "1";
        "dfs.namenode.name.dir" = "/var/hadoop/hdfs/namenode";
        "dfs.datanode.data.dir" = "/var/hadoop/hdfs/datanode";
      };

      yarnSite = {
        "yarn.resourcemanager.hostname" = "localhost";
        "yarn.nodemanager.aux-services" = "mapreduce_shuffle";
      };

      # Enable services based on the selected role
      hdfs.namenode.enable = lib.mkIf (config.services.hadoop.role == "leader"
        || config.services.hadoop.role == "both") true;
      hdfs.namenode.formatOnInit = lib.mkIf (config.services.hadoop.role
        == "leader" || config.services.hadoop.role == "both") true;
      hdfs.namenode.restartIfChanged = lib.mkIf (config.services.hadoop.role
        == "leader" || config.services.hadoop.role == "both") true;

      hdfs.datanode.enable = lib.mkIf (config.services.hadoop.role == "worker"
        || config.services.hadoop.role == "both") true;

      yarn.resourcemanager.enable = lib.mkIf (config.services.hadoop.role
        == "leader" || config.services.hadoop.role == "both") true;
      yarn.resourcemanager.restartIfChanged = lib.mkIf
        (config.services.hadoop.role == "leader" || config.services.hadoop.role
          == "both") true;
      yarn.resourcemanager.openFirewall = lib.mkIf (config.services.hadoop.role
        == "leader" || config.services.hadoop.role == "both") true;

      yarn.nodemanager.enable = lib.mkIf (config.services.hadoop.role
        == "worker" || config.services.hadoop.role == "both") true;
      yarn.nodemanager.restartIfChanged = lib.mkIf (config.services.hadoop.role
        == "worker" || config.services.hadoop.role == "both") true;
      yarn.nodemanager.resource.memoryMB = lib.mkIf (config.services.hadoop.role
        == "worker" || config.services.hadoop.role == "both") 4096;
      yarn.nodemanager.resource.cpuVCores = lib.mkIf
        (config.services.hadoop.role == "worker" || config.services.hadoop.role
          == "both") 2;
    };

    environment.systemPackages = with pkgs; [ config.services.hadoop.package ];
  };
}
