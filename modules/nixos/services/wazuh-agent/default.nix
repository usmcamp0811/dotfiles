{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.wazuh-agent;

  agentConfig = pkgs.writeText "wazuh-agent-ossec.conf" ''
    <ossec_config>
      <client>
        <server>
          <address>${cfg.managerAddress}</address>
          <port>${toString cfg.managerPort}</port>
          <protocol>${cfg.protocol}</protocol>
        </server>
        <notify_time>${toString cfg.notifyTime}</notify_time>
        <time-reconnect>${toString cfg.timeReconnect}</time-reconnect>
        <auto_restart>yes</auto_restart>
      </client>
      <logging>
        <log_format>${cfg.logFormat}</log_format>
      </logging>
      ${cfg.extraConfig}
    </ossec_config>
  '';
in {
  options.fmf.services.wazuh-agent = with types; {
    enable = mkBoolOpt false "Enable the Wazuh agent service.";

    package = mkOpt package pkgs.fmf.wazuh-agent "Wazuh agent package to run.";

    stateDir =
      mkOpt str "/var/lib/wazuh-agent" "Mutable Wazuh agent state directory.";

    managerAddress =
      mkOpt str "127.0.0.1" "Wazuh manager address to connect to.";
    managerPort = mkOpt int 1514 "Wazuh manager ingestion port.";

    protocol = mkOption {
      type = enum [ "tcp" "udp" ];
      default = "tcp";
      description = "Protocol used to connect to manager.";
    };

    notifyTime = mkOpt int 10 "Agent notify interval in seconds.";
    timeReconnect = mkOpt int 60 "Reconnect interval in seconds.";

    user = mkOpt str "wazuh-agent" "User to run Wazuh agent.";
    group = mkOpt str "wazuh-agent" "Group to run Wazuh agent.";

    logFormat = mkOption {
      type = enum [ "plain" "json" ];
      default = "plain";
      description = "Wazuh agent log format.";
    };

    extraConfig = mkOption {
      type = lines;
      default = "";
      description = "Extra XML blocks appended inside <ossec_config>.";
    };
  };

  config = mkIf cfg.enable {
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.stateDir;
      description = "Wazuh agent service user";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/etc 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/logs 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/queue 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/var 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/tmp 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/wodles 0750 ${cfg.user} ${cfg.group} -"
    ];

    environment.systemPackages = [ cfg.package ];

    systemd.services.wazuh-agent = {
      description = "Wazuh Agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      preStart = ''
        if [ ! -f ${cfg.stateDir}/.fmf-package ] || [ "$(cat ${cfg.stateDir}/.fmf-package)" != "${cfg.package}" ]; then
          for path in bin lib active-response; do
            if [ -e ${cfg.package}/$path ]; then
              rm -rf ${cfg.stateDir}/$path
              cp -r ${cfg.package}/$path ${cfg.stateDir}/
            fi
          done

          for path in ruleset framework; do
            if [ -e ${cfg.package}/$path ]; then
              rm -rf ${cfg.stateDir}/$path
              cp -r ${cfg.package}/$path ${cfg.stateDir}/
            fi
          done

          printf '%s' ${cfg.package} > ${cfg.stateDir}/.fmf-package
        fi

        install -D -m 0640 -o ${cfg.user} -g ${cfg.group} ${agentConfig} ${cfg.stateDir}/etc/ossec.conf
        chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
      '';

      serviceConfig = {
        Type = "forking";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        Environment =
          [ "WAZUH_HOME=${cfg.stateDir}" "DIRECTORY=${cfg.stateDir}" ];
        ExecStart = "${cfg.stateDir}/bin/wazuh-control start";
        ExecStop = "${cfg.stateDir}/bin/wazuh-control stop";
        Restart = "on-failure";
        RestartSec = 10;
        KillMode = "process";
      };
    };
  };
}
