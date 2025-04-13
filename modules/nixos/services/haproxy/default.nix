{ lib
, config
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.haproxy;
in
{
  options.campground.services.haproxy = with types; {
    enable = mkBoolOpt false "Enable HAProxy.";
    haIP = mkOpt str "*" "IP to listen on";
    defaults = mkOption {
      type = attrsOf str;
      default = {
        mode = "tcp";
        "timeout connect" = "5s";
        "timeout client" = "50s";
        "timeout server" = "50s";
      };
      description = "Default settings for HAProxy.";
    };

    stats = {
      enable = mkBoolOpt false "Enable HAProxy stats endpoint.";
      port = mkOption {
        type = types.port;
        default = 9000;
        description = "Port to expose HAProxy stats on.";
      };
      uri = mkOption {
        type = types.str;
        default = "/";
        description = "URI path to access the stats page.";
      };
    };
    frontends = mkOption {
      type = attrsOf (submodule {
        options = {
          bind = mkOption {
            type = listOf str;
            default = [ "${cfg.haIP}:80" ];
            description = "List of IP:port bindings for the frontend.";
          };
          backend = mkOption {
            type = str;
            description = "The backend to route traffic to.";
          };
          options = mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional frontend options.";
          };
        };
      });
      default = { };
      description = "Frontends for HAProxy.";
    };

    backends = mkOption {
      type = attrsOf (submodule {
        options = {
          balance = mkOption {
            type = str;
            default = "roundrobin";
            description = "Load balancing algorithm.";
          };
          servers = mkOption {
            type = attrsOf (submodule {
              options = {
                ip = mkOption {
                  type = str;
                  description = "IP or hostname of the backend server.";
                };
                port = mkOption {
                  type = int;
                  default = 80;
                  description = "Port for the backend server.";
                };
                options = mkOption {
                  type = listOf str;
                  default = [ "check" ];
                  description = "Additional server options.";
                };
              };
            });
            default = { };
            description = "List of backend servers.";
          };
          options = mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional backend options (e.g. mode tcp, option tcp-check).";
          };
        };
      });
      default = { };
      description = "Backends for HAProxy.";
    };
  };

  config = mkIf cfg.enable {
    services.haproxy = {
      enable = true;

      config = ''
        defaults
          ${
          lib.concatStringsSep "\n  "
          (mapAttrsToList (name: value: "${name} ${value}") cfg.defaults)
        }

        ${lib.concatStringsSep "\n\n" (mapAttrsToList (name: frontend: ''
            frontend ${name}
              ${
              lib.concatStringsSep "\n  "
              (map (bind: "bind ${bind}") frontend.bind)
            }
              default_backend ${frontend.backend}
              ${lib.concatStringsSep "\n  " frontend.options}
          '')
          cfg.frontends)}

        ${lib.concatStringsSep "\n\n" (mapAttrsToList (name: backend: ''
            backend ${name}
              ${lib.concatStringsSep "\n  " backend.options}
              balance ${backend.balance}
              ${
              lib.concatStringsSep "\n  " (mapAttrsToList (srvName: srv: "server ${srvName} ${srv.ip}:${toString srv.port} ${
                  lib.concatStringsSep " " srv.options
                }")
                backend.servers)
            }
          '')
          cfg.backends)}

        ${optionalString cfg.stats.enable ''
          listen stats
            bind ${cfg.haIP}:${toString cfg.stats.port}
            mode http
            stats enable
            stats uri ${cfg.stats.uri}
        ''}
      '';
    };
  };
}
