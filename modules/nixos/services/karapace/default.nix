{ host ? "", options, config, lib, pkgs, ... }:

with lib;
with lib.fmf;
let cfg = config.fmf.services.karapace;
in {
  options.fmf.services.karapace = with types; {
    enable = mkBoolOpt false "Whether or not to enable Karapace.";
    port = mkOpt int cfg.config.port "Port to use";
    config = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Karapace configuration settings as a Nix attribute set.";
      example = literalExpression ''
        {
          advertised_hostname = "lucas";
          bootstrap_uri = "kafka://lucas:9092";
          registry_host = "schema-registry.lan.aicampground.com";
          registry_port = 8081;
          host = "0.0.0.0";
          port = 8082;
          admin_metadata_max_age = 600;
          log_level = "INFO";
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users.apache-kafka = {
      isSystemUser = true;
      group = "apache-kafka";
      home = "/var/lib/apache-kafka";
      createHome = true;
    };

    users.groups.apache-kafka = { };

    systemd.services.karapace = {
      description = "Karapace Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # Pre-start script to convert Nix configuration to JSON
      serviceConfig = {
        ExecStart =
          "${pkgs.fmf.karapace}/bin/karapace /var/lib/apache-kafka/config.json";
        Restart = "always";
        User = "apache-kafka";
        Group = "apache-kafka";
      };
      preStart = ''
        ${pkgs.jq}/bin/jq -n '${
          builtins.toJSON cfg.config
        }' > /var/lib/apache-kafka/config.json
      '';
    };

  };
}
