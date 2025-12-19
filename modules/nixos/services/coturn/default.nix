{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.coturn;
in {
  options.fmf.services.coturn = with types; {
    enable = mkBoolOpt false "Enable Coturn";
    cert-fqdn = mkOpt str "" "Fully qualified domain name for the certificate";
    external-ip = mkOpt str "" "External IP address of the server";
    coturn-denied-ips = mkOpt (listOf str) [ ] "List of denied peer IPs";
    turn-ports = mkOpt (listOf int) [ ] "List of TURN ports";
    min-port = mkOpt int 49152 "Minimum port for Coturn";
    max-port = mkOpt int 49262 "Maximum port for Coturn";
    realm = mkOpt str "turn.aicampground.com" "Realm for Coturn authentication";
  };

  config = mkIf cfg.enable {
    services.coturn = {
      enable = true;
      use-auth-secret = true;
      static-auth-secret-file = config.sops.secrets.auth-secret.path;
      realm = cfg.realm;
      min-port = cfg.min-port;
      max-port = cfg.max-port;
      no-cli = true;
      cert = mkIf (cfg.cert-fqdn != "") ''
        ${config.security.acme.certs.${cfg.cert-fqdn}.directory}/fullchain.pem
      '';
      pkey = mkIf (cfg.cert-fqdn != "") ''
        ${config.security.acme.certs.${cfg.cert-fqdn}.directory}/key.pem
      '';
      no-tcp-relay = true;
      extraConfig = ''
        fingerprint
        external-ip=${cfg.external-ip}
        userdb=/var/lib/coturn/turnserver.db
        no-tlsv1
        no-tlsv1_1
        no-rfc5780
        no-stun-backward-compatibility
        response-origin-only-with-rfc5780
        no-multicast-peers
      '' + lib.strings.concatMapStringsSep "\n" (x: "denied-peer-ip=${x}")
        cfg.coturn-denied-ips;
    };

    systemd.services.coturn.serviceConfig.StateDirectory = "coturn";
    systemd.services.coturn.serviceConfig.Group = lib.mkForce "acme";

    networking = {
      firewall = {
        allowedUDPPortRanges = with config.services.coturn; [{
          from = cfg.min-port;
          to = cfg.max-port;
        }];
        allowedUDPPorts = cfg.turn-ports;
        allowedTCPPorts = cfg.turn-ports;
      };
    };
  };
}
