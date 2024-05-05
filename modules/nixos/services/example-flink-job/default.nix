{ host ? "", lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.example-flink-job;
in {
  options.campground.services.example-flink-job = with types; {
    enable = mkBoolOpt false "Apache Flink service";
  };

  config = mkIf cfg.enable {

    campground.services.flink-task-manager = enabled;

    systemd.services.example-flink-job = {
      description = "Example Flink Job";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      wants = [ "network.target" ];
      environment = {
        FLINK_CONF_DIR = "/var/lib/flink/conf";
        JAVA_HOME = pkgs.openjdk11;
      };
      serviceConfig = {
        # User = "flink";
        # Group = "flink";
        Type = "simple";
        # RemainAfterExit = true;
        ExecStop = "${pkgs.flink}/opt/flink/bin/jobmanager.sh stop";
        Restart = "on-failure";
      };
      script = ''
        export PATH=${pkgs.campground.example-flink-job.python}/bin:$PATH
        ${pkgs.flink}/opt/flink/bin/jobmanager.sh start
        ${pkgs.flink}/bin/flink run \
        -py ${pkgs.campground.example-flink-job}/src/job/job.py \
        --jarfile ${pkgs.campground.flink-connector-kafka} \
        --jobname example_job
      '';
    };

    # systemd.services.example-flink-job = {
    #   description = "Example Flink Job";
    #   after = [ "network.target" "flink-task-manager.service" ];
    #   wants = [ "network.target" "flink-task-manager.service" ];
    #   wantedBy = [ "multi-user.target" ];
    #   environment = {
    #     FLINK_CONF_DIR = "/var/lib/flink/conf";
    #     JAVA_HOME = pkgs.openjdk11;
    #   };
    #   serviceConfig = {
    #     User = "flink";
    #     Group = "flink";
    #     Restart = "on-failure";
    #     PermissionsStartOnly = true;
    #   };
    #   script = ''
    #     ${pkgs.flink}/bin/flink run \
    #       -py ${pkgs.campground.example-flink-job}/src/job/job.py \
    #       -pyclientexec ${pkgs.campground.example-flink-job.python}/bin/python \
    #       -pypath ${pkgs.campground.example-flink-job.python} \
    #       --jarfile ${pkgs.campground.flink-connector-kafka} \
    #       --jobname example_job --inputtopic example-topic --outputtopic example-output --errortopic example-error --kafka_server lucas:9092
    #   '';
    #   preStart = ''
    #     ${pkgs.flink}/opt/flink/bin/jobmanager.sh start-foreground
    #   '';
    #   postStop = ''
    #     ${pkgs.flink}/opt/flink/bin/jobmanager.sh stop
    #   '';
    # };
  };
}
