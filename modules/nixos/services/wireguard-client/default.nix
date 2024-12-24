{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.wireguard-client;
in {
  options.campground.services.wireguard-client = with types; {
    enable = mkBoolOpt false "Enable OpenVPN Server;";
    publicKey = mkOpt str "123456789" "The client's public key";
    endpoint = mkOpt str "vpn.aicampground.com" "VPN Domain Name / IP address.";
    port = mkOpt int "1149" "Port to use for the VPN";
    ips = mkOpt (listOf str) [ "10.100.0.5/32" ]
      "List of IPs of the client's end of the tunner interface.";
    ip = mkOpt str "10.100.0.5/32"
      "List of IPs of the client's end of the tunner interface.";
    vpn-name = mkOpt str "campnet" "Name of the VPN";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/wireguard"
      "The Vault path to the Server Cert in Vault";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version used for tls key";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      checkReversePath = false;
      allowedUDPPorts =
        [ cfg.port ]; # Clients and peers can use the same port, see listenport
    };

    systemd.services.getWireguardConf = {
      description = "Fetch Private Key from Vault";
      serviceConfig = {
        User = "root";
        Type = "oneshot";
      };
      # TODO: maybe change wantedBy to something else
      wantedBy = [ "graphical.target" ];
      script = ''
        # Add the certificate to nmcli
        if ${pkgs.networkmanager}/bin/nmcli con show | grep -q ${cfg.vpn-name}; then
          ${pkgs.networkmanager}/bin/nmcli con delete id ${cfg.vpn-name}
        fi
        ${pkgs.networkmanager}/bin/nmcli con import type wireguard file /tmp/detsys-vault/${cfg.vpn-name}.conf
        ${pkgs.networkmanager}/bin/nmcli con down ${cfg.vpn-name}
      '';
    };

    campground.services.vault-agent.services.getWireguardConf = {
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
      secrets = {
        file = {
          files = {
            "${cfg.vpn-name}.conf" = {
              text = ''
                [Interface]
                # Client private key
                PrivateKey = {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${config.networking.hostName} }}{{ else }}{{ .Data.data.${config.networking.hostName} }}{{ end }}{{ end }}
                # Client IP address
                Address = ${cfg.ip}
                # Optional: Uncomment the next line to set a DNS server
                DNS = 10.8.0.1

                [Peer]
                # Server public key
                PublicKey = ${cfg.publicKey}
                # Pre-shared key
                PresharedKey = {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.presharedKey }}{{ else }}{{ .Data.data.presharedKey }}{{ end }}{{ end }}
                # Server endpoint (replace with server's public IP address and port)
                Endpoint = {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.vpnEndpoint }}{{ else }}{{ .Data.data.vpnEndpoint }}{{ end }}{{ end }}
                # Allowed IPs (0.0.0.0/0 allows routing all traffic through the VPN)
                AllowedIPs = 0.0.0.0/0, ::/0
                # Optional: Uncomment for persistent keepalive (useful behind NAT)
                # PersistentKeepalive = 25
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
