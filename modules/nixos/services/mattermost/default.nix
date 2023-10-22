{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.mattermost;
in
{
  options.campground.services.mattermost = with types; {
    enable = mkBoolOpt false "Enable Mattermost;";
  };

  config = mkIf cfg.enable {
    services.postgresql.enable = lib.mkForce true;
    services.mattermost = {
      enable = true;

      siteUrl = "https://mattermost.aicampground.com";
      listenAddress = "0.0.0.0:8065";
      mutableConfig = true;
      matterircd = {
        enable = true;
      };

      # TODO reevaluate option on fresh install
      # Database was created before this option existed. Also using this
      # requires to put add the password to the nix store.
      localDatabaseCreate = false;

      extraConfig = {
        ServiceSettings = {
          EnableEmailInvitations = true;
          EnableOAuthServiceProvider = true;
          TrustedProxyIPHeader = [ "X-Forwarded-For" "X-Real-IP" ];
          AllowCorsFrom = "*";
        };

        FileSettings.Directory = "/var/lib/mattermost/files";
      };
    };


    systemd.services.mattermost = {

      serviceConfig = {

        # EnvironmentFile = "/tmp/detsys-";

        Environment = [

          # TODO Check syntax for header
          "MM_SQLSETTINGS_DRIVERNAME=postgres"
          "MM_SQLSETTINGS_DATASOURCE=postgres://mattermost@/mattermost?host=/run/postgresql/"

          # Secret envfile contains:
          # MM_EMAILSETTINGS_CONNECTIONSECURITY=
          # MM_EMAILSETTINGS_ENABLEPREVIEWMODEBANNER=
          # MM_EMAILSETTINGS_ENABLESMTPAUTH=
          # MM_EMAILSETTINGS_FEEDBACKEMAIL=
          # MM_EMAILSETTINGS_PUSHNOTIFICATIONCONTENTS=
          # MM_EMAILSETTINGS_REPLYTOADDRESS=
          # MM_EMAILSETTINGS_SENDEMAILNOTIFICATIONS=
          # MM_EMAILSETTINGS_SMTPPASSWORD=
          # MM_EMAILSETTINGS_SMTPPORT=
          # MM_EMAILSETTINGS_SMTPSERVER=
          # MM_EMAILSETTINGS_SMTPUSERNAME=
          # MM_FILESETTINGS_PUBLICLINKSALT=
          # MM_SQLSETTINGS_ATRESTENCRYPTKEY=
          # MM_SQLSETTINGS_DATASOURCE=
          # MM_EXTRA_SQLSETTINGS_DB_PASSWORD=
        ];
      };
    };

    # campground.services.vault-agent.services.mattermost = {
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
    #         "mattermost.env" = {
    #           text = ''{{ with secret "${cfg.vault-path}" }}
    # MM_SQLSETTINGS_DRIVERNAME=postgres
    # MM_SQLSETTINGS_DATASOURCE=postgres://mmuser@/mattermost?host=/run/postgresql/    
    # {{ if eq "${cfg.kvVersion}" "v1" }}
    # {{ else }}
    # {{ end }}
    # {{ end }}'';
    #           permissions = "0600";
    #           change-action = "restart";
    #         };
    #       };
    #     };
    #   };
    # };

  };
}
