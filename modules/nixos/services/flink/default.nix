{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.flink;
  fink-conf = lib.mkMerge [
    "${cfg.package}/opt/flink/conf/flink-conf.yaml"
    (pkgs.writeText "flink-conf.yaml" (lib.generators.toYAML { } cfg.config))
  ];
in {
  options.campground.services.flink = with types; {
    enable = mkBoolOpt false "Apache Flink service";
    package = mkOpt package pkgs.flink "The Flink package to use.";
    config = mkOpt attrs {
      # Default Flink configuration options
      taskmanager.numberOfTaskSlots = "4";
      jobmanager.execution.failover-strategy = "region";
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
      environment = { FLINK_CONF_DIR = "/var/lib/flink/conf"; };
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/start-cluster.sh";
        ExecStop = "${cfg.package}/bin/stop-cluster.sh";
        Restart = "on-failure";
        PermissionsStartOnly = true;
      };
      preStart = ''
        mkdir -p /var/lib/flink/conf
        cp -r ${pkgs.flink}/opt/flink/conf/* /var/lib/flink/conf/
        cp ${flink-conf} /var/lib/flink/conf/flink-conf.yaml
      '';
    };
  };
}
