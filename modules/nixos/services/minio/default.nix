{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.minio;
in {
  options.fmf.services.minio = with types; {
    enable = mkBoolOpt false "Enable minio;";
    dataDir =
      mkOpt str "/var/lib/minio/data" "Data directory for MinIO server.";
    configDir = mkOpt str "/var/lib/minio/config" "Config directory";
    listenAddress = mkOpt str ":9000" "IP addres and port of the server";
    consoleAddress = mkOpt str ":9001" "IP addres and port of the web UI.";
    region =
      mkOpt str "us-east-1"
      "where the server is at... defaults to the same as AWS";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/minio"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    services.minio = {
      enable = true;
      listenAddress = cfg.listenAddress;
      consoleAddress = cfg.consoleAddress;
      dataDir = [cfg.dataDir];
      configDir = cfg.configDir;
      region = cfg.region;
      rootCredentialsFile = "/var/lib/minio/minio-root-creds";
    };

    networking.firewall.allowedTCPPorts = [ 9000 9001 ];

    systemd.services.copyMinioCreds = {
      description = "Copy the creds file for Minio";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.coreutils}/bin/cp /tmp/detsys-vault/minio-root-creds /var/lib/minio/minio-root-creds";
      };
      wantedBy = ["multi-user.target"];
      before = ["minio.service"];
    };
    fmf.services.vault-agent.services.copyMinioCreds = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [
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
      };
      secrets = {
        file = {
          files = {
            "minio-root-creds" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}
                MINIO_ROOT_USER='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.user }}{{ else }}{{ .Data.data.user }}{{ end }}'
                MINIO_ROOT_PASSWORD='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.password }}{{ else }}{{ .Data.data.password }}{{ end }}'
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
