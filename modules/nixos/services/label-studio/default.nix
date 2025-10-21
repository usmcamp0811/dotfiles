{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.label-studio;
in {
  options.campground.services.label-studio = with types; {
    enable = mkBoolOpt false "Enable label-studio;";
    port = mkOpt int 8080 "Port to listen on";
    dbURI =
      mkOpt str
      "postgresql+psycopg2://labelstudio:@/labelstudio?host=/var/run/postgresql"
      "DB URI";
    s3EndpointURL =
      mkOpt str "https://s3-api.lan.aicampground.com" "S3 Storage Endpoint URL";
    s3Region = mkOpt str "us-east-1" "S3 Region";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/mlflow"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
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
    # environment.systemPackages = with pkgs; [ label_studio ];
    # users.users.labelstudio = {
    #   isNormalUser = false;
    #   isSystemUser = true;
    #   description = "Label Studio System User";
    #   group = "labelstudio";
    #   extraGroups = [
    #     "labelstudio"
    #   ]; # Optional if you want the user to be in additional groups
    #   home = "/var/lib/label-studio";
    # };
    # users.groups.labelstudio = { };
    #
    # systemd.tmpfiles.rules = [ "d /var/lib/label-studio 0755 labelstudio labelstudio -" ];
    #
    # systemd.services.label-studio = {
    #   description = "Label Studio";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   environment = {
    #     DJANGO_DB = "postgresql";
    #     POSTGRE_NAME = "labelstudio";
    #     POSTGRE_USER = "labelstudio";
    #     POSTGRE_PORT = "5432";
    #     POSTGRE_HOST = "/var/run/postgresql";
    #     LABEL_STUDIO_DISABLE_SIGNUP_WITHOUT_LINK = "true";
    #     S3_ENDPOINT = "${cfg.s3EndpointURL}";
    #   };
    #   script = ''
    #     ${pkgs.label_studio}/bin/label-studio start --database "${cfg.dbURI}" --host 127.0.0.1 --port 5903
    #   '';
    #   serviceConfig = {
    #     User = "labelstudio";
    #     Restart = "always";
    #   };
    # };
    #
    # campground.services.postgresql = {
    #   enable = true;
    #   authentication = [
    #     "local labelstudio labelstudio trust"
    #   ];
    #   databases = [
    #     {
    #       name = "labelstudio";
    #       user = "labelstudio";
    #     }
    #   ];
    # };
    # services.nginx = {
    #   enable = true;
    #   virtualHosts = {
    #     "label-studio.lan" = {
    #       listen = [
    #         {
    #           addr = "0.0.0.0";
    #           port = cfg.port;
    #         }
    #       ]; # Specify the port here
    #       http2 = true;
    #       locations."/" = {
    #         proxyPass = "http://127.0.0.1:5903";
    #         proxyWebsockets = true;
    #       };
    #     };
    #   };
    # };
    #
    # campground.services.vault-agent.services.label-studio = {
    #   settings = {
    #     vault.address = cfg.vault-address;
    #     auto_auth = {
    #       method = [
    #         {
    #           type = "approle";
    #           config = {
    #             role_id_file_path = cfg.role-id;
    #             secret_id_file_path = cfg.secret-id;
    #             remove_secret_id_file_after_reading = false;
    #           };
    #         }
    #       ];
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
