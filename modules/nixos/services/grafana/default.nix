{ lib
, pkgs
, config
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.grafana;
  dashboards = ./dashboards;
  dashboardProviders = [
    {
      name = "Backup Monitor";
      type = "file";
      options = { path = ./dashboards/backup-monitor.json; };
    }
    {
      name = "Campground Budget";
      type = "file";
      options = { path = ./dashboards/budget-dashboard.json; };
    }
  ];
in
{
  options.campground.services.grafana = with types; {
    enable = mkBoolOpt false "Enable an Grafana;";
    port = mkOpt int 7443 "Port to Host the grafana server on.";
    datasources = mkOption {
      type = types.listOf (types.attrsOf types.anything);
      description = "A list of datasources.";
      default = [ ];
    };
    dashboards = mkOption {
      type = types.listOf (types.attrsOf types.str);
      description = "A list of dashboard providers";
      default = [ ];
    };
    domain =
      mkOpt str "grafana.lan.aicampground.com"
        "Domain to Host the grafana server on.";
    oidc-domain = mkOpt str "auth.aicampground.com" "ODIC Domain";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/grafana"
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
    # systemd.services.copy-grafana-dashboards = {
    #   description = "Copy Grafana dashboards from Nix store to writable path";
    #   wantedBy = [ "grafana.service" ];
    #   before = [ "grafana.service" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart =
    #       let
    #         dashboardSrc = ./dashboards; # same as in your module
    #       in
    #       "${pkgs.bash}/bin/bash -c 'cp -r ${dashboardSrc}/* /var/lib/grafana/dashboards/'";
    #   };
    # };
    #
    # systemd.tmpfiles.rules = [
    #   "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    # ];

    services.grafana = {
      enable = true;
      provision = {
        # enable = true;
        alerting = {
          rules = {
            settings = {
              apiVersion = 1;
              groups = [
                {
                  orgId = 1;
                  name = "backups";
                  folder = "backup_alerts";
                  interval = "5m";
                  rules = [
                    {
                      uid = "adxql03nljqwwa";
                      title = "Borg Backup Alert";
                      condition = "A";
                      data = [
                        {
                          refId = "A";
                          relativeTimeRange = {
                            from = 86400;
                            to = 0;
                          };
                          datasourceUid = "PBFA97CFB590B2093";
                          model = {
                            datasource = {
                              type = "prometheus";
                              uid = "PBFA97CFB590B2093";
                            };
                            editorMode = "code";
                            expr = ''
                              (
                                borg_backup_success{exported_job=~"webb_rsync|webb_campground|daly_rsync|daly_campground"} == 0
                              )
                              or
                              (
                                (time() - borg_backup_last_run{exported_job=~"webb_rsync|webb_campground|daly_rsync|daly_campground"}) > 86400
                              )
                            '';
                            instant = true;
                            intervalMs = 1000;
                            legendFormat = "__auto";
                            maxDataPoints = 43200;
                            range = false;
                            refId = "A";
                          };
                        }
                      ];
                      dashboardUid = "fdxl9e1g0zaiod";
                      panelId = 1;
                      noDataState = "OK";
                      execErrState = "Error";
                      for = "5m";
                      annotations = {
                        __dashboardUid__ = "fdxl9e1g0zaiod";
                        __panelId__ = "1";
                        summary = "One or more of your backups did not run successfully.";
                      };
                      labels = { };
                      isPaused = false;
                    }
                  ];
                }
              ];
            };
          };
        };
        datasources = {
          settings = {
            apiVersion = 1;
            datasources = cfg.datasources;
          };
        };
        dashboards = {
          settings = {
            apiVersion = 1;

            providers =
              cfg.dashboards
              ++ dashboardProviders; # Combine dashboards
          };
        };
      };
      settings = {
        auth.oauth_auto_login = true;
        auth.signout_redirect_url = "https://${cfg.oidc-domain}/application/o/grafana/end-session/";

        "auth.generic_oauth" = {
          name = "authentik";
          enabled = true;
          client_id = "$__env{CLIENT_ID}";
          client_secret = "$__env{CLIENT_SECRET}";
          scopes = "openid profile email";
          auth_url = "https://${cfg.oidc-domain}/application/o/authorize/";
          token_url = "https://${cfg.oidc-domain}/application/o/token/";
          api_url = "https://${cfg.oidc-domain}/application/o/userinfo/";
          role_attribute_path = "contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Editor'";
        };
        smtp = {
          enabled = true;
          host = "$__env{SMTP_HOST}";
          user = "$__env{SMTP_USER}";
          password = "$__env{SMTP_PASS}";
          fromAddress = "no-reply@grafana.aicampground.com";
          startTLS_policy = "MandatoryStartTLS";
        };
        security = {
          admin_user = "$__env{ADMIN_USER}";
          admin_password = "$__env{ADMIN_PASSWORD}";
        };
        server = {
          root_url = "https://${cfg.domain}";
          # Listening Address
          http_addr = "0.0.0.0";
          # and Port
          http_port = cfg.port;
          # Grafana needs to know on which domain and URL it's running
          domain = cfg.domain;
          serve_from_sub_path = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    campground.services.vault-agent.services.grafana = {
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
      secrets.environment.templates = {
        grafana = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            ADMIN_USER='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_USER }}{{ else }}{{ .Data.data.ADMIN_USER }}{{ end }}'
            ADMIN_PASSWORD='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_PASSWORD }}{{ else }}{{ .Data.data.ADMIN_PASSWORD }}{{ end }}'
            SMTP_USER='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_USER }}{{ else }}{{ .Data.data.SMTP_USER }}{{ end }}'
            SMTP_HOST='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_HOST }}{{ else }}{{ .Data.data.SMTP_HOST }}{{ end }}'
            SMTP_PASS='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_PASS }}{{ else }}{{ .Data.data.SMTP_PASS }}{{ end }}'
            CLIENT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLIENT_ID }}{{ else }}{{ .Data.data.CLIENT_ID }}{{ end }}'
            CLIENT_SECRET='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLIENT_SECRET }}{{ else }}{{ .Data.data.CLIENT_SECRET }}{{ end }}'
            {{ end }}
          '';
        };
      };
    };
  };
}
