{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.spark;
in {
  options.fmf.services.spark = with types; {
    enable = mkBoolOpt false "Enable a Spark server.";
    port = mkOpt int 8081 "Port to host the Spark server on.";
    confDir = mkOpt str "${cfg.package}/conf"
      "Spark configuration directory. Spark will use the configuration files (spark-defaults.conf, spark-env.sh, log4j.properties, etc) from this directory.";
    master.extraEnvironment = mkOpt attrs { }
      "Extra environment variables to pass to spark master. See spark-standalone documentation.";
    worker.master = mkOpt str "spark://localhost:7077"
      "Address of the Spark master for the worker.";
    package = mkOpt package pkgs.spark "The spark package to use.";
    logDir = mkOpt str "/var/log/spark" "Spark log directory.";
    worker.workDir = mkOpt str "/var/lib/spark" "Spark worker work dir.";
    master.bind = mkOpt str "0.0.0.0" "Address to bind the Spark master.";
    worker.enable = mkBoolOpt false "Enable Spark worker.";
    master.enable = mkBoolOpt false "Enable Spark master.";
    worker.extraEnvironment =
      mkOpt attrs { } "Extra environment variables to pass to spark worker.";
    worker.restartIfChanged =
      mkBoolOpt true "Restart Spark worker if configuration changes.";
    master.restartIfChanged =
      mkBoolOpt true "Restart Spark master if configuration changes.";
    # role-id =
    #   mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
    #   "Absolute path to the Vault role-id";
    # secret-id =
    #   mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
    #   "Absolute path to the Vault secret-id";
    # vault-path = mkOpt str "secret/campground/spark"
    #   "The Vault path to the KV containing the Spark Secrets.";
    # kvVersion = mkOption {
    #   type = enum [ "v1" "v2" ];
    #   default = "v2";
    #   description = "KV store version";
    # };
    # vault-address = mkOption {
    #   type = str;
    #   default = config.fmf.services.vault-agent.settings.vault.address;
    #   description = "The address of your Vault";
    # };
  };

  config = mkIf cfg.enable {
    services.spark = {
      confDir = cfg.confDir;
      master.extraEnvironment = cfg.master.extraEnvironment;
      worker.master = cfg.worker.master;
      package = cfg.package;
      logDir = cfg.logDir;
      worker.workDir = cfg.worker.workDir;
      master.bind = cfg.master.bind;
      worker.enable = cfg.worker.enable;
      master.enable = cfg.master.enable;
      worker.extraEnvironment = cfg.worker.extraEnvironment;
      worker.restartIfChanged = cfg.worker.restartIfChanged;
      master.restartIfChanged = cfg.master.restartIfChanged;
    };

    # fmf.services.vault-agent.services.copy-spark-env = {
    #   settings = {
    #     vault.address = cfg.vault-address;
    #     auto_auth = {
    #       method = [{
    #         type = "approle";
    #         config = {
    #           role_id_file_path = cfg.role-id;
    #           secret_id_file_path = cfg.secret-id;
    #           remove_secret_id_file_after_reading = false;
    #         };
    #       }];
    #     };
    #   };
    #   secrets = {
    #     file = {
    #       files = {
    #         "spark.env" = {
    #           text = ''
    #             SPARK_SECRET_KEY={{ with secret "{cfg.vault-path}" }}{{ if eq "{cfg.kvVersion}" "v1" }}{{ .Data.SPARK_SECRET_KEY }}{{ else }}{{ .Data.data.SPARK_SECRET_KEY }}{{ end }}{{ end }}
    #           '';
    #           permissions = "0600";
    #           change-action = "restart";
    #         };
    #       };
    #     };
    #   };
    # };
  };
}
