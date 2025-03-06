{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.haproxy;
in {
  options.campground.services.haproxy = with types; {
    enable = mkBoolOpt false "Enable HAProxy;";
    defaults = mkOption {
      type = types.attrsOf types.str;
      default = {
        mode = "tcp";
        "timeout connect" = "5s";
        "timeout client" = "50s";
        "timeout server" = "50s";
      };
      description = "Default settings for HAProxy.";
    };
    frontend-ip = mkOpt str "*" "IP to access HAProxy on";
    frontend-port = mkOpt str "80" "Port to access HAProxy on";
    backendServers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          port = mkOption {
            type = types.int;
            default = 8080;
            description = "Port for the backend server.";
          };
        };
      });
      default = { };
      description = "Backend servers for HAProxy.";
    };
  };

  config = mkIf cfg.enable {
    services.haproxy = {
      enable = true;
      config = ''
        global
          log /dev/log local0
          chroot /var/lib/haproxy
          user haproxy
          group haproxy

        defaults
          ${
            lib.concatStringsSep "\n"
            (lib.mapAttrsToList (name: value: "${name} ${value}") cfg.defaults)
          }

        frontend http-in
          bind ${cfg.frontend-ip}:${cfg.frontend-port}
          default_backend servers

        backend servers
          balance roundrobin
          ${
            lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
              "server ${name} ${name}:${toString value.port} check")
              cfg.backendServers)
          }
      '';
    };
  };
}
