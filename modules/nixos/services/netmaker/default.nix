{ lib, config, pkgs, ... }:
{
  options.campground.services.ntp = with types; {
    enable = mkBoolOpt false "Enable CAC Support;";
  };

  config = mkIf cfg.enable {
    # networking.timeServers = options.networking.timeServers.default ++ [ "0.arch.pool.ntp.org" ]; 
    services.ntp.enable = true;
  };
}

{ config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.services.netmaker;
  generateConfig = {
    apihost = cfg.apiHost;
    apiport = cfg.apiPort;
    masterkey = cfg.masterKey;
    allowedorigin = cfg.allowedOrigin;
    restbackend = cfg.restBackend;
    clientmode = cfg.clientMode;
    dnsmode = cfg.dnsMode;
    sqlconn = cfg.sqlConn;
    disableremoteipcheck = cfg.disableRemoteIpCheck;
    version = cfg.version;
    rce = cfg.rce;
    mqhost = cfg.mqHost;
    nodeid = cfg.nodeId;
    messagequeuebackend = cfg.messageQueueBackend;
    database = cfg.database;
    verbosity = cfg.verbosity;
    authprovider = cfg.authProvider;
    displaykeys = cfg.displayKeys;
    manageiptables = cfg.manageIptables;
    portforwardservices = cfg.portForwardServices;
    hostnetwork = cfg.hostNetwork;
    mqport = cfg.mqPort;
    mqserverport = cfg.mqServerPort;
    server = cfg.server;
  };
  configFile = pkgs.writeText "netmaker-config.yml" (builtins.toJSON generateConfig);
in {
  options.services.netmaker = {
    enable = mkEnableOption "Netmaker";
    
    # Netmaker specific options
    apiHost = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "API host for Netmaker.";
    };
    apiPort = mkOption {
      type = types.str;
      default = "8081";
      description = "API port for Netmaker.";
    };
    masterKey = mkOption {
      type = types.str;
      default = "secretkey";
      description = "Master key for Netmaker.";
    };
    # Add similar options for other configuration parameters...
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.campground.netmaker-ui pkgs.netmaker ]; # Ensure netmaker package is available

    campground.services.postgresql = {
      enable = true;
      databases = [ 
        { 
          name = "netmaker"; 
          user = "netmaker"; 
        } 
      ];
    };

    networking.firewall = {
      allowedTCPPorts = [
        # Caddy Proxy
        80
        443
        # TURN Server
        3479
        8089
      ];
      allowedUDPPorts = [
        51821 # Wireguard
      ];
    };
    # # Get HTTPS certificates from LetsEncrypt
    # security.acme = {
    #   acceptTerms = true;
    #   defaults.email = "gio@damelio.net";
    #
    #   certs."nm.gio.ninja" = {
    #     dnsProvider = "cloudflare";
    #     domain = "*.${baseDomain}";
    #     extraDomainNames = [baseDomain];
    #     credentialsFile = config.age.secrets.cert_netmaker_gio_ninja.path;
    #   };
    # };


    # Setup Mosquitto MQTT message broker
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          port = 8883;
          users.netmaker.passwordFile = "/var/lib/netmaker/netmaker-pass";
          settings = {
            protocol = "websockets";
            allow_anonymous = false;
          };
        }
        {
          port = 1883;
          users.netmaker.passwordFile = "/var/lib/netmaker/netmaker-pass";
          settings = {
            protocol = "websockets";
            allow_anonymous = false;
          };
        }
      ];
    };

    # Use Caddy to reverse proxy
    # services.caddy = {
    #   enable = true;
    #   group = "acme";
    #
    #   virtualHosts."https://dashboard.nm.gio.ninja" = {
    #     useACMEHost = "nm.gio.ninja";
    #     extraConfig = ''
    #       header {
    #           Access-Control-Allow-Origin *.${baseDomain}
    #           Strict-Transport-Security "max-age=31536000;"
    #           X-XSS-Protection "1; mode=block"
    #           X-Frame-Options "SAMEORIGIN"
    #           X-Robots-Tag "none"
    #           -Server
    #       }
    #       root * ${n.netmaker-ui}
    #       file_server
    #     '';
    #   };
    #
    #   virtualHosts."wss://broker.nm.gio.ninja" = {
    #     useACMEHost = "nm.gio.ninja";
    #     extraConfig = ''
    #       reverse_proxy ws://localhost:8883
    #     '';
    #   };
    # };
    systemd.services.netmaker = {

      description = "Netmaker Wireguard Mesh Network";

      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.netmaker}/bin/netmaker -c ${netmakerConfig}";
        EnvironmentFile = config.age.secrets.service_netmaker_envfile.path;
      };
      script = ''
        ${pkgs.netmaker}/bin/netmaker -c ${configFile}
      '';
      serviceConfig = {
        # EnvironmentFile = config.age.secrets.service_netmaker_envfile.path;
        Restart = "always";
        DynamicUser = true;
        User = "netmaker";
        Group = "netmaker";
      };
    };

    networking.firewall.allowedTCPPorts = [ (builtins.toInteger cfg.apiPort) ]; # Open port for Netmaker UI/API
  };
}



