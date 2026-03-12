{ lib, config, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.mattermost;
in {
  options.fmf.services.mattermost = with types; {
    enable = mkBoolOpt false "Enable Mattermost;";
  };

  config = mkIf cfg.enable {
    fmf.services.postgresql = {
      enable = true;
      authentication = [ "local mattermost mattermost trust" ];
      databases = [{
        name = "mattermost";
        user = "mattermost";
      }];
    };

    # have to force this since we create the db elsewhere
    services.postgresql = { enable = lib.mkForce true; };
    # open ports for calls
    # 8065: HTTP, 8045: Gossip protocol, 8443: Calls signaling, 3478: STUN
    # UDP port range 10000-10100 for WebRTC media streams
    networking.firewall.allowedTCPPorts = [ 3478 8443 8045 8065 ];
    networking.firewall.allowedUDPPorts = [ 3478 8443 8045 ];
    networking.firewall.allowedUDPPortRanges = [{
      from = 10000;
      to = 10100;
    }];

    services.mattermost = {
      enable = true;
      host = "0.0.0.0";
      port = 8065;
      database.fromEnvironment = true;
      database.create = false;

      siteUrl = "https://mattermost.aicampground.com";
      # TODO: Move away from mutable
      mutableConfig = true;
      matterircd = { enable = true; };

      # TODO reevaluate option on fresh install
      # Database was created before this option existed. Also using this
      # requires to put add the password to the nix store.
      localDatabaseCreate = false;

      settings = {
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
          "MM_SERVICESETTINGS_ALLOWEDUNTRUSTEDINTERNALCONNECTIONS=n8n.lan.aicampground.com"

          # Calls plugin configuration
          # Use public STUN servers for NAT traversal
          "MM_PLUGINSETTINGS_PLUGINS_COM.MATTERMOST.CALLS_ICEHOSTOVERRIDE=mattermost.aicampground.com"
          "MM_PLUGINSETTINGS_PLUGINS_COM.MATTERMOST.CALLS_RTCDSERVICEURL=https://mattermost.aicampground.com:8443"
          ''
            MM_PLUGINSETTINGS_PLUGINS_COM.MATTERMOST.CALLS_ICESERVERS=[{"urls":["stun:stun.l.google.com:19302","stun:stun1.l.google.com:19302"]}]''
          "MM_PLUGINSETTINGS_PLUGINS_COM.MATTERMOST.CALLS_UDPSERVERPORT=8443"

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
  };
}
