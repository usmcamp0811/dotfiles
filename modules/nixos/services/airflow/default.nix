{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.airflow;
  isServer = cfg.role == "server";

  airflowPackage = pkgs.apache-airflow.override {
    enabledProviders = ["celery" "postgres"];
  };

  airflowEnvironment = {
    AIRFLOW_HOME = cfg.path;
    AIRFLOW__API__BASE_URL = cfg.baseUrl;
    AIRFLOW__CORE__DAGS_FOLDER = "${cfg.path}/dags";
    AIRFLOW__CORE__EXECUTION_API_SERVER_URL = "http://${cfg.serverAddress}:${toString cfg.port}/execution/";
    AIRFLOW__CORE__EXECUTOR = "CeleryExecutor";
    AIRFLOW__CORE__LOAD_EXAMPLES = "false";
  };

  serverEnvironment =
    airflowEnvironment
    // {
      AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE = "/tmp/detsys-vault/airflow-passwords.json";
      AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS = "admin:admin";
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN = "postgresql+psycopg2://airflow@/airflow?host=/run/postgresql";
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN_ASYNC = "postgresql+asyncpg://airflow@/airflow?host=/run/postgresql";
    };

  serviceConfig = {
    User = "airflow";
    Group = "airflow";
    WorkingDirectory = cfg.path;
    ReadWritePaths = [cfg.path];
    NoNewPrivileges = true;
    ProtectHome = true;
    ProtectSystem = "strict";
  };

  vaultSettings = {
    vault.address = cfg.vault-address;
    auto_auth.method = [
      {
        type = "approle";
        config = {
          role_id_file_path = cfg.role-id;
          secret_id_file_path = cfg.secret-id;
          remove_secret_id_file_after_reading = false;
        };
      }
    ];
  };

  vaultEnvironment = {
    settings = vaultSettings;
    secrets.environment.templates.airflow.text = ''
      {{ with secret "${cfg.vault-path}" }}
      AIRFLOW__CORE__FERNET_KEY='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.fernet_key }}{{ else }}{{ .Data.data.fernet_key }}{{ end }}'
      AIRFLOW__API__SECRET_KEY='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.api_secret_key }}{{ else }}{{ .Data.data.api_secret_key }}{{ end }}'
      AIRFLOW__CELERY__BROKER_URL='redis://:{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.redis_password }}{{ else }}{{ .Data.data.redis_password }}{{ end }}@${cfg.serverAddress}:6379/0'
      AIRFLOW__CELERY__RESULT_BACKEND='db+postgresql+psycopg2://airflow_result:{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.airflow_result }}{{ else }}{{ .Data.data.airflow_result }}{{ end }}@${cfg.serverAddress}:5432/airflow_result'
      ${optionalString isServer ''AIRFLOW__API_AUTH__JWT_SECRET='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.jwt_secret }}{{ else }}{{ .Data.data.jwt_secret }}{{ end }}' ''}
      {{ end }}
    '';
  };
in {
  options.fmf.services.airflow = with types; {
    enable = mkBoolOpt false "Enable Apache Airflow.";
    role = mkOpt (enum ["server" "worker"]) "server" "Airflow node role.";
    package = mkOpt package airflowPackage "Apache Airflow package to use.";
    port = mkOpt port 8888 "Port for the Airflow API server.";
    ip = mkOpt str "127.0.0.1" "Address on which the Airflow API server listens.";
    serverAddress = mkOpt str "127.0.0.1" "Address of the Airflow server node.";
    path = mkOpt str "/var/lib/airflow" "Airflow state directory.";
    baseUrl = mkOpt str "http://${cfg.serverAddress}:${toString cfg.port}" "External URL for Airflow.";
    workerConcurrency = mkOpt ints.positive 4 "Number of concurrent tasks on a worker.";
    openFirewall = mkBoolOpt false "Open the ports required by this Airflow role.";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/airflow"
      "Vault KV path containing the Airflow secrets";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of Vault";
    };
  };

  config = mkIf cfg.enable {
    users.users.airflow = {
      isSystemUser = true;
      group = "airflow";
      home = cfg.path;
    };
    users.groups.airflow = {};

    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0750 airflow airflow -"
      "d ${cfg.path}/dags 0750 airflow airflow -"
      "d ${cfg.path}/logs 0750 airflow airflow -"
      "d ${cfg.path}/plugins 0750 airflow airflow -"
    ];

    fmf.services.postgresql = mkIf isServer {
      enable = true;
      enableTCPIP = true;
      vault-path = cfg.vault-path;
      authentication = [
        "local all postgres peer"
        "local airflow airflow trust"
        "local airflow_result airflow_result trust"
        "host airflow_result airflow_result 10.8.0.0/24 md5"
        "host all all 0.0.0.0/0 reject"
        "host all all ::/0 reject"
      ];
      databases = [
        {
          name = "airflow";
          user = "airflow";
        }
        {
          name = "airflow_result";
          user = "airflow_result";
        }
      ];
    };

    services.redis.servers.airflow = mkIf isServer {
      enable = true;
      bind = "0.0.0.0";
      port = 6379;
      appendOnly = true;
      requirePassFile = "/tmp/detsys-vault/redis-password";
    };

    systemd.services = mkMerge [
      (mkIf isServer {
        airflow-migrate = {
          description = "Migrate the Apache Airflow metadata database";
          after = ["network.target" "postgresql.service"];
          requires = ["postgresql.service"];
          environment = serverEnvironment;
          serviceConfig =
            serviceConfig
            // {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${cfg.package}/bin/airflow db migrate";
            };
        };

        airflow-api-server = {
          description = "Apache Airflow API server";
          after = ["airflow-migrate.service" "network.target"];
          requires = ["airflow-migrate.service"];
          wantedBy = ["multi-user.target"];
          environment = serverEnvironment;
          serviceConfig =
            serviceConfig
            // {
              ExecStart = "${cfg.package}/bin/airflow api-server --host ${cfg.ip} --port ${toString cfg.port} --proxy-headers";
              Restart = "on-failure";
              RestartSec = 5;
            };
        };

        airflow-scheduler = {
          description = "Apache Airflow scheduler";
          after = ["airflow-migrate.service" "network.target"];
          requires = ["airflow-migrate.service"];
          wantedBy = ["multi-user.target"];
          environment = serverEnvironment;
          serviceConfig =
            serviceConfig
            // {
              ExecStart = "${cfg.package}/bin/airflow scheduler";
              Restart = "on-failure";
              RestartSec = 5;
            };
        };

        airflow-dag-processor = {
          description = "Apache Airflow DAG processor";
          after = ["airflow-migrate.service" "network.target"];
          requires = ["airflow-migrate.service"];
          wantedBy = ["multi-user.target"];
          environment = serverEnvironment;
          serviceConfig =
            serviceConfig
            // {
              ExecStart = "${cfg.package}/bin/airflow dag-processor";
              Restart = "on-failure";
              RestartSec = 5;
            };
        };

        airflow-triggerer = {
          description = "Apache Airflow triggerer";
          after = ["airflow-migrate.service" "network.target"];
          requires = ["airflow-migrate.service"];
          wantedBy = ["multi-user.target"];
          environment = serverEnvironment;
          serviceConfig =
            serviceConfig
            // {
              ExecStart = "${cfg.package}/bin/airflow triggerer";
              Restart = "on-failure";
              RestartSec = 5;
            };
        };
      })

      (mkIf (!isServer) {
        airflow-worker = {
          description = "Apache Airflow Celery worker";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          wantedBy = ["multi-user.target"];
          environment = airflowEnvironment;
          serviceConfig =
            serviceConfig
            // {
              ExecStart = "${cfg.package}/bin/airflow celery worker --celery-hostname ${config.networking.hostName}@%h --concurrency ${toString cfg.workerConcurrency} --queues default";
              Restart = "on-failure";
              RestartSec = 5;
            };
        };
      })
    ];

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (
      if isServer
      then [cfg.port 5432 6379]
      else [8793]
    );

    fmf.services.vault-agent.services = mkMerge [
      (mkIf isServer {
        airflow-migrate = vaultEnvironment;
        airflow-api-server = recursiveUpdate vaultEnvironment {
          secrets.file.files."airflow-passwords.json" = {
            text = ''
              {{ with secret "${cfg.vault-path}" }}
              {"admin": {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.admin_password | toJSON }}{{ else }}{{ .Data.data.admin_password | toJSON }}{{ end }}}
              {{ end }}
            '';
            permissions = "0600";
            change-action = "restart";
          };
        };
        airflow-scheduler = vaultEnvironment;
        airflow-dag-processor = vaultEnvironment;
        airflow-triggerer = vaultEnvironment;
        redis-airflow = {
          settings = vaultSettings;
          secrets.file.files."redis-password" = {
            text = ''
              {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.redis_password }}{{ else }}{{ .Data.data.redis_password }}{{ end }}{{ end }}
            '';
            permissions = "0600";
            change-action = "restart";
          };
        };
      })
      (mkIf (!isServer) {
        airflow-worker = vaultEnvironment;
      })
    ];
  };
}
