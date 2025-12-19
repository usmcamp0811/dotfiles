{ lib
, pkgs
, config
, ...
}:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.crowdsec;
in {
  options.fmf.services.crowdsec = with types; {
    enable = mkBoolOpt false "Enable crowdsec.";
    listen_uri = mkOpt str "0.0.0.0:10808" "URI to listen on";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/crowdsec"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
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
    services.crowdsec = {
      enable = true;

      # acquisitions moved into localConfig for nixpkgs module
      localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
      ];

      # settings.general is a YAML value; put api.server inside it
      settings.general = {
        api.server = {
          enable = true;
          listen_uri = cfg.listen_uri;
        };
      };
    };

    fmf.services.vault-agent.services.crowdsec = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = cfg."role-id";
                secret_id_file_path = cfg."secret-id";
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };
      secrets = {
        file.files = {
          "crowdsec_key" = {
            text = ''
              {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.key }}{{ else }}{{ .Data.data.key }}{{ end }}{{ end }}
            '';
            permissions = "0600";
            change-action = "restart";
          };
        };
      };
    };
  };
}
