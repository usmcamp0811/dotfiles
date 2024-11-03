{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.n8n;
in {
  options.campground.services.n8n = with types; {
    enable = mkBoolOpt false "Enable n8n;";
    webhookUrl = mkOpt str "n8n.lan.aicampground.com"
      "WEBHOOK_URL for n8n, in case we’re running behind a reverse proxy. This cannot be set through configuration and must reside in an environment variable.";
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/mlflow"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    services.n8n = { enable = true; };
    systemd.services.n8n.runtimeDependencies =
      [ pkgs.nodejs pkgs.nodePackages.npm ];

    # campground.services.vault-agent.services.n8n = {
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
    #   secrets.environment.templates = {
    #     mlflow = {
    #       text = ''
    #         {{ with secret "${cfg.vault-path}" }}
    #         AWS_ACCESS_KEY_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AWS_ACCESS_KEY_ID }}{{ else }}{{ .Data.data.AWS_ACCESS_KEY_ID }}{{ end }}'
    #         AWS_SECRET_ACCESS_KEY='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AWS_SECRET_ACCESS_KEY }}{{ else }}{{ .Data.data.AWS_SECRET_ACCESS_KEY }}{{ end }}'
    #         {{ end }}
    #       '';
    #     };
    #   };
    # };
  };
}
