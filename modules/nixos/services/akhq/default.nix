{ host ? "", options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.services.akhq;
  ahkq-config = builtins.toYAML cfg.settings;
in {
  options.campground.services.akhq = with types; {
    enable = mkBoolOpt false "Whether or not to enable kafka configuration.";
    connection-name = mkOpt str "campground"
        "Name of the connection";
    bootstrap-server = mkOpt str "${host}:9092" "Kafka server address";
    port = mkOpt int 8435 "Port to Host the Apache Kafka HQ server.";
    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Configuration settings for AKHQ in Nix expression format.";
      example = literalExpression ''
        {
          akhq.connections.ssl-dev.properties = {
            bootstrap.servers = "host.aivencloud.com:12835";
            security.protocol = "SSL";
            ssl.truststore.location = "/path/to/truststore/avnadmin.truststore.jks";
            ssl.truststore.password = "password";
            ssl.keystore.type = "PKCS12";
            ssl.keystore.location = "/path/to/keystore/avnadmin.keystore.p12";
            ssl.keystore.password = "password";
            ssl.key.password = "password";
          };
          akhq.connections.ssl-dev.schema-registry.url = "https://host.aivencloud.com:12838";
          ...
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.akhq = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.campground.akhq}/bin/akhq";
        Restart = "always";
      };
      environment = {
        MICRONAUT_CONFIG_FILES = ${ahkq-config};
      };
    };

  };
}
