{ lib, config, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.zookeeper;
in
{
  options.fmf.services.zookeeper = with types; {
    enable = mkBoolOpt false "Enable Kafka;";
    id = mkOpt int 0 "Server ID";
    servers = mkOption {
      description = lib.mdDoc "All Zookeeper Servers.";
      default = "";
      type = types.lines;
      example = ''
        server.0=lucas:2888:3888
      '';
    };

    logging = mkOption {
      description = lib.mdDoc "Zookeeper logging configuration.";
      default = ''
        zookeeper.root.logger=INFO, CONSOLE
        log4j.rootLogger=INFO, CONSOLE
        log4j.logger.org.apache.zookeeper.audit.Log4jAuditLogger=INFO, CONSOLE
        log4j.appender.CONSOLE=org.apache.log4j.ConsoleAppender
        log4j.appender.CONSOLE.layout=org.apache.log4j.PatternLayout
        log4j.appender.CONSOLE.layout.ConversionPattern=[myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n
      '';
      type = types.lines;
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/zookeeper";
      description = lib.mdDoc ''
        Data directory for Zookeeper
      '';
    };
  };

  config = mkIf cfg.enable {
    services.zookeeper = {
      id = cfg.id;
      enable = true;
      servers = cfg.servers;
      logging = cfg.logging;
      dataDir = cfg.dataDir;
      purgeInterval = 24; # Configures the purge interval to 24 hours.
      extraConf = ''
        initLimit=5
        syncLimit=2
        tickTime=2000
        admin.enableServer=true
        admin.serverPort=8438
      ''; # Add your desired admin port here
    };

    networking.firewall.allowedTCPPorts = [ 2181 2888 3888 8438 ];
  };
}
