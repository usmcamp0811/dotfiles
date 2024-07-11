{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.coturn;
in {
  options.campground.services.coturn = with types; {
    enable = mkBoolOpt false "Enable Coturn;";
  };

  config = mkIf cfg.enable {
    services.coturn = {
      enable = true;
      use-auth-secret = true;
      static-auth-secret-file = config.sops.secrets.auth-secret.path;
      realm = "turn.aicampground.com";
      min-port = 49152;
      max-port = 49262;
      no-cli = true;
      cert =
        "${config.security.acme.certs.${cert-fqdn}.directory}/fullchain.pem";
      pkey = "${config.security.acme.certs.${cert-fqdn}.directory}/key.pem";
      no-tcp-relay = true;
      extraConfig = ''
        fingerprint
        external-ip=${external-ip}
        userdb=/var/lib/coturn/turnserver.db
        no-tlsv1
        no-tlsv1_1
        no-rfc5780
        no-stun-backward-compatibility
        response-origin-only-with-rfc5780
        no-multicast-peers
      '' + lib.strings.concatMapStringsSep "\n" (x: "denied-peer-ip=${x}")
        coturn-denied-ips;
    };
    systemd.services.coturn.serviceConfig.StateDirectory = "coturn";
    systemd.services.coturn.serviceConfig.Group = lib.mkForce "acme";

    networking = {
      firewall = {
        allowedUDPPortRanges = with config.services.coturn; [{
          from = min-port;
          to = max-port;
        }];
        allowedUDPPorts = turn-ports;
        allowedTCPPorts = turn-ports;
      };
    };
  };
}
