{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.flink;
in {
  options.campground.services.flink = with types; {
    enable = mkBoolOpt false "Apache Flink service";
    package = mkOpt package pkgs.flink "The Flink package to use.";
    config = mkOpt attrs {
      "env.java.opts.all" = "--add-exports=java.base/sun.net.util=ALL-UNNAMED --add-exports=java.rmi/sun.rmi.registry=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED --add-exports=java.security.jgss/sun.security.krb5=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.text=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED";
      "jobmanager.rpc.address" = "localhost";
      "jobmanager.rpc.port" = "6123";
      "jobmanager.bind-host" = "0.0.0.0";
      "jobmanager.memory.process.size" = "1600m";
      "taskmanager.bind-host" = "0.0.0.0";
      "taskmanager.host" = "localhost";
      "taskmanager.memory.process.size" = "1728m";
      "taskmanager.numberOfTaskSlots" = "4";
      "parallelism.default" = "1";
      "jobmanager.execution.failover-strategy" = "region";
      "rest.port" = "8081";
      "rest.address" = "localhost";
      "rest.bind-port" = "8080-8090";
      "rest.bind-address" = "0.0.0.0";
      "env.java.home" = "/nix/store/6375rn8kiq9pn4pgdkdiqgvg8b0gdycy-openjdk-19.0.2+7";
      "env.log.dir" = "/tmp/flink-logs";
    } "Additional configuration attributes for Flink.";
  };

  config = mkIf cfg.enable {

    users.users.flink = {
      isSystemUser = true;
      group = "flink";
      home = "/var/lib/flink";
      createHome = true;
    };

    users.groups.flink = { };

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.services.flink = {
      description = "Apache Flink service";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = { 
        FLINK_CONF_DIR = "/var/lib/flink/conf";
        JAVA_HOME = pkgs.openjdk11;
      };
      serviceConfig = {
        User = "flink";
        Group = "flink";
        ExecStart = "${cfg.package}/opt/flink/bin/start-cluster.sh";
        ExecStop = "${cfg.package}/opt/flink/bin/stop-cluster.sh";
        Restart = "on-failure";
        PermissionsStartOnly = true;
      };
      preStart = ''
        mkdir -p /var/lib/flink/conf
        cp -r ${pkgs.flink}/opt/flink/conf/* /var/lib/flink/conf/
        cat > /var/lib/flink/conf/flink-conf.yaml <<EOF
        ${generators.toYAML {} cfg.config}
EOF
      '';
    };
  };
}
