{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.wireguard-client;
in
{
  options.campground.services.wireguard-client = with types; {
    enable = mkBoolOpt false "Enable OpenVPN Server;";
    pulicKey = mkOpt str "123456789" "The client's public key";
    endpoint = mkOpt str "vpn.aicampground.com" "VPN Domain Name / IP address.";
    port = mkOpt int "1149" "Port to use for the VPN";
    ips = mkOpt listOf str [ "10.100.0.5/32"] "List of IPs of the client's end of the tunner interface.";

    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "campground-pki/issue/vpn-server-role" "The Vault path to the Server Cert in Vault";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
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
      allowedUDPPorts = [ cfg.port ]; # Clients and peers can use the same port, see listenport
    };

    # Enable WireGuard
    networking.wireguard.interfaces = {
      # "wg0" is the network interface name. You can name the interface arbitrarily.
      wg0 = {
        # Determines the IP address and subnet of the client's end of the tunnel interface.
        ips = cfg.ips;
        listenPort = cfg.port; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

        # Path to the private key file.
        #
        # Note: The private key can also be included inline via the privateKey option,
        # but this makes the private key world-readable; thus, using privateKeyFile is
        # recommended.
        privateKeyFile = "/var/lib/wireguard/${config.networking.hostName}";
        presharedKeyFile = "/var/lib/wireguard/preshared-private-key";

        peers = [
          # For a client configuration, one peer entry for the server will suffice.

          {
            # Public key of the server (not a file path).
            publicKey = cfg.publicKey;

            # Forward all the traffic via VPN.
            allowedIPs = [ "0.0.0.0/0" ];
            # Or forward only particular subnets
            #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];

            # Set this to the server IP and port.
            endpoint = "${cfg.endpoint}:${toString cfg.port}"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          }
        ];
      };
    };
    systemd.services.getWireguardKeys = {
      description = "Fetch Private Key from Vault";
      serviceConfig = {
        Type = "oneshot";
        User = "root";  # Use the root user to create the folder and set permissions
        ExecStart = "/bin/sh /tmp/detsys-vault/getWireguardKeys.sh";
      };
      wantedBy = [ "multi-user.target" ];
    };

    campground.services.vault-agent.services.getWireguardKeys = {
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
            "getWireguardKeys.sh" = {
              text = ''
                #!/bin/sh
                set -e  # exit immediately on error

                # Create directory for VPN certificates
                mkdir -p /var/lib/wireguard/

                cat <<EOL > /var/lib/wireguard/${config.networking.hostName}
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data."${config.networking.hostName}" }}{{ else }}{{ .Data.data."${config.networking.hostName}" }}{{ end }}{{ end }}
                EOL
                cat <<EOL > /var/lib/wireguard/preshared-private-key
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.privateKey }}{{ else }}{{ .Data.data.privateKey }}{{ end }}{{ end }}
                EOL

                # Fix permissions
                chmod -R 0600 /var/lib/wireguard
              '';
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
