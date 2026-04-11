{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.wazuh-manager;

  managerConfig = pkgs.writeText "wazuh-manager-ossec.conf" ''
    <ossec_config>
      <global>
        <jsonout_output>${
          if cfg.jsonOutput then "yes" else "no"
        }</jsonout_output>
        <alerts_log>${if cfg.alertsLog then "yes" else "no"}</alerts_log>
        <logall>${if cfg.logAll then "yes" else "no"}</logall>
      </global>
      <remote>
        <connection>secure</connection>
        <port>${toString cfg.agentPort}</port>
        <protocol>${cfg.protocol}</protocol>
      </remote>
      <auth>
        <disabled>no</disabled>
        <port>${toString cfg.registrationPort}</port>
        <use_source_ip>no</use_source_ip>
        <purge>yes</purge>
      </auth>
      <api>
        <https>${if cfg.api.enableTls then "yes" else "no"}</https>
        <port>${toString cfg.api.port}</port>
      </api>
      ${cfg.extraConfig}
    </ossec_config>
  '';
in {
  options.fmf.services.wazuh-manager = with types; {
    enable = mkBoolOpt false "Enable the Wazuh manager service.";

    package =
      mkOpt package pkgs.fmf.wazuh-manager "Wazuh manager package to run.";

    stateDir = mkOpt str "/var/lib/wazuh-manager"
      "Mutable Wazuh manager state directory.";

    user = mkOpt str "wazuh-manager" "User to run Wazuh manager.";
    group = mkOpt str "wazuh-manager" "Group to run Wazuh manager.";

    protocol = mkOption {
      type = enum [ "tcp" "udp" ];
      default = "tcp";
      description = "Protocol manager listens on for agents.";
    };

    agentPort = mkOpt int 1514 "Port for agent event forwarding.";
    registrationPort = mkOpt int 1515 "Port for agent enrollment.";

    openFirewall = mkBoolOpt true "Open manager ports in firewall.";

    jsonOutput = mkBoolOpt true "Enable JSON output.";
    alertsLog = mkBoolOpt true "Enable alerts log output.";
    logAll = mkBoolOpt false "Enable full event logging.";

    api = {
      port = mkOpt int 55000 "Wazuh API port.";
      enableTls = mkBoolOpt false "Enable TLS at Wazuh API layer.";
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
      description = "Wazuh manager service user";
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

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.registrationPort cfg.api.port ]
        ++ optional (cfg.protocol == "tcp") cfg.agentPort;
      allowedUDPPorts = optional (cfg.protocol == "udp") cfg.agentPort;
    };

    systemd.services.wazuh-manager = {
      description = "Wazuh Manager";
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

        install -D -m 0640 -o ${cfg.user} -g ${cfg.group} ${managerConfig} ${cfg.stateDir}/etc/ossec.conf
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
