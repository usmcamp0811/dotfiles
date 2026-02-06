{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
# THIS IS BORKED
# Think the problem is with the version of Python but not certain.. 
# do know starting with version 1.4.0 they switch to Poetry so 
# the package will need to be reworked to support poetry. 
let
  cfg = config.fmf.services.funkwhale;

  funkwhaleEnvTemplate = ''
    {{ with secret "${cfg.vault-path}" }}
    DJANGO_SECRET_KEY='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.django_secret_key }}{{ else }}{{ .Data.data.django_secret_key }}{{ end }}'
    EMAIL_CONFIG='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.email_config }}{{ else }}{{ .Data.data.email_config }}{{ end }}'
    {{ end }}
  '';
in {
  options.fmf.services.funkwhale = with types; {
    enable = mkEnableOption "Funkwhale";

    apiIp = mkOpt str "0.0.0.0" "IP to access the API on";
    webWorkers = mkOpt int 4 "Number of Workers";
    apiPort = mkOpt int 15012 "API Port number";
    frontIp = mkOpt str "0.0.0.0" "IP to access the Front End on";
    frontPort = mkOpt int 18234 "Frontend Port";
  };

  config = mkIf cfg.enable {
    fmf.services.postgresql = {
      enable = true;
      authentication = [ "local funkwhale funkwhale trust" ];
      databases = [{
        name = "funkwhale";
        user = "funkwhale";
      }];
    };
    services.funkwhale = {
      enable = true;
      user = "funkwhale";
      group = "funkwhale";
      database = {
        createLocally = false;
        name = "funkwhale";
        user = "funkwhale";
        socket = "/run/postgresql";
      };

      dataDir = "/mnt/media/music";

      typesenseKey = "my-secret-typesense-key";

      apiIp = "0.0.0.0";
      webWorkers = 4;
      apiPort = 15012;
      frontIp = "0.0.0.0";
      frontPort = 18234;

      hostname = "funkwhale.lan.aicampground.com";
      # protocol = "https";
      # forceSSL = true;

      # emailConfig = "smtp+ssl://user:password@myemail.host:465";
      defaultFromEmail = "no-reply@funkwhale.aicampground.com";

      api = {
        mediaRoot = "/mnt/media/music/media";
        staticRoot = "/var/lib/funkwhale/static";
      };

      musicPath = "/mnt/media/music";
    };

    fmf.services.vault-agent.services = {
      funkwhale = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets.environment.templates = {
          funkwhale = { text = funkwhaleEnvTemplate; };
        };
      };

      funkwhale-psql-init = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets.environment.templates = {
          funkwhale = { text = funkwhaleEnvTemplate; };
        };
      };

      funkwhale-init = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets.environment.templates = {
          funkwhale = { text = funkwhaleEnvTemplate; };
        };
      };

      funkwhale-server = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets.environment.templates = {
          funkwhale = { text = funkwhaleEnvTemplate; };
        };
      };

      funkwhale-worker = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets.environment.templates = {
          funkwhale = { text = funkwhaleEnvTemplate; };
        };
      };

      funkwhale-beat = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets.environment.templates = {
          funkwhale = { text = funkwhaleEnvTemplate; };
        };
      };
    };
  };
}
