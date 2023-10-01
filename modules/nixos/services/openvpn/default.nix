{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.openvpn;

in
{
  options.campground.services.openvpn = with types; {
    enable = mkBoolOpt false "Enable OpenVPN Server;";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "campground-vpn/issue/server-role" "The Vault path to the Server Cert in Vault";
    vault-client-path = mkOpt str "campground-vpn/issue/client-role" "The Vault path to the Client Cert in Vault"; 
    vault-ca-path = mkOpt str "campground-vpn/cert/ca" "The Vault path to the CA Cert in Vault"; 
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    common-name = mkOpt str "vpn.${cfg.domain-name}" "Common Name for Server Certs";
    domain-name = mkOpt str "aicampground.com" "Domain Name for Certs";
    vpn-cert-csv = mkOpt str "/var/lib/vault/ovpn/vpn-certs.csv" "CSV with Cert Serial Numbers";
  };

  config = mkIf cfg.enable {
    users.users.ovpn = {
      isSystemUser = true;
      group = "ovpn";
      description = "OpenVPN service user";
    };

    users.groups.ovpn = {};

    boot.kernel.sysctl."net.ipv4.ip_forward" = 1; # so we can get to the internet

    services.openvpn.servers = {
      campground = {
        config = ''
          port 1194
          proto udp
          dev tun
          ca /var/lib/vault/ovpn/ca.crt
          cert /var/lib/vault/ovpn/server.crt
          key /var/lib/vault/ovpn/server.key
          dh /var/lib/vault/ovpn/dh.pem 
          server 10.8.1.0 255.255.255.0
          ifconfig-pool-persist ipp.txt
          keepalive 10 120
          comp-lzo
          persist-key
          persist-tun
          client-to-client
          push "redirect-gateway def1"
          status openvpn-status.log
          verb 3
        '';
      };
    };

# TODO: Refactor so that this just renews the server cert 
# TODO: Refactor to make the `copyVPNcerts.sh` script is installed and can be run independent of the systmed service
# TODO: Clean up or otherwise just make things look better and more uniform

    systemd.timers.genVPNserver-cert = {
      description = "Timer for Generate VPN Client Certs";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily"; # Runs every day at midnight
      };
      unitConfig = {
        PartOf = [ "genVPNserver-cert.service" ];
      };
    };

    systemd.services.genVPNserver-cert = {
      description = "Get VPN Server Certs from Vault";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/copyVPNcerts.sh";
        after = [ "vault-agent.service" ];
        before = [ "openvpn-campground.service" ];
      };
      wantedBy = [ "multi-user.target" ];
    };
# TODO: Refactor this so that we rotate server certs in a similar manner as the client certs
    campground.services.vault-agent.services.genVPNserver-cert = {
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
            "copyVPNcerts.sh" = {
              text = ''
                #!/bin/sh
                set -e  # exit immediately on error

                # Create directory for VPN certificates
                mkdir -p /var/lib/vault/ovpn/

                # Create directory for client certificates
                mkdir -p /var/lib/vault/ovpn/clients/

                # Generate server.crt
                cat <<EOL > /var/lib/vault/ovpn/server.crt
                {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.certificate }}
                {{ end }}
                EOL

                # Generate server.key
                cat <<EOL > /var/lib/vault/ovpn/server.key
                {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.private_key }}
                {{ end }}
                EOL

                # Generate ca.crt
                cat <<EOL > /var/lib/vault/ovpn/ca.crt
                {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.issuing_ca }}
                {{ end }}
                EOL

                # # Generate Diffie-Hellman parameters
                # ${pkgs.openssl}/bin/openssl dhparam -out /var/lib/vault/ovpn/dh.pem 2048

                # Fix permissions
                chown -R ovpn:ovpn /var/lib/vault/ovpn/*
                chmod -R 0600 /var/lib/vault/ovpn
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
