{ host ? "", lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.flink-task-manager;
in {
  options.campground.services.flink-task-manager = with types; {
    enable = mkBoolOpt false "Apache Flink service";
    masters = mkOpt (lib.types.listOf lib.types.str) [ host ] "Mast Flink Node";
    workers = mkOpt (lib.types.listOf lib.types.str) [ host ] "Worker Nodes";
    flink-conf = mkOpt str ''
      env.java.opts.all: --add-exports=java.base/sun.net.util=ALL-UNNAMED --add-exports=java.rmi/sun.rmi.registry=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED --add-exports=java.security.jgss/sun.security.krb5=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.text=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED
      jobmanager.rpc.address: ${host}
      jobmanager.rpc.port: 6123
      jobmanager.bind-host: 0.0.0.0
      jobmanager.memory.process.size: 1600m
      taskmanager.bind-host: 0.0.0.0
      taskmanager.host: ${host}
      taskmanager.memory.process.size: 1728m
      taskmanager.numberOfTaskSlots: 4
      parallelism.default: 1
      jobmanager.execution.failover-strategy: region
      rest.port: 8081
      rest.address: ${host}
      rest.bind-port: 8080-8090
      rest.bind-address: 0.0.0.0
      env.log.dir: /var/lib/flink/flink-logs
      python.tmpdir: /tmp/pyflink
    '' "Additional configuration attributes for Flink.";
  };

  config = mkIf cfg.enable {

    users.users.flink = {
      isSystemUser = true;
      group = "flink";
      home = "/var/lib/flink";
      createHome = true;
    };

    users.groups.flink = { };

    systemd.services.flink-task-manager = {
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
        Restart = "on-failure";
        PermissionsStartOnly = true;
      };
      # "${cfg.package}/opt/flink/bin/standalone-job.sh start-foreground";
      script = ''
        export PATH=${pkgs.openssh}/bin:$PATH
        ${pkgs.flink}/opt/flink/bin/taskmanager.sh start-foreground
      '';
      preStart = ''
        mkdir -p /var/lib/flink/conf
        mkdir -p /var/lib/flink/flink-logs
        cp -r ${pkgs.flink}/opt/flink/conf/* /var/lib/flink/conf/
        echo "${
          lib.concatStringsSep "\n" cfg.masters
        }" > /var/lib/flink/conf/masters
        echo "${
          lib.concatStringsSep "\n" cfg.workers
        }" > /var/lib/flink/conf/workers
        echo "${cfg.flink-conf}" > /var/lib/flink/conf/flink-conf.yaml
      '';
      postStop = ''
        ${pkgs.flink}/opt/flink/bin/taskmanager.sh stop
      '';
    };
  };
}
