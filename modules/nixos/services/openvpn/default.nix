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
    vault-path = mkOpt str "pki/issue/campground-vpn-server-role" "The Vault path to the Cert in Vault";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    common-name = mkOpt str "vpn.aicampground.com" "Common Name for Server Certs";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
    ];

    users.users.ovpn = {
      isSystemUser = true;
      group = "ovpn";
      description = "OpenVPN service user";
    };

    users.groups.ovpn = {};

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
          status openvpn-status.log
          verb 3
        '';
      };
    };

    systemd.services.copyVPNcerts = {
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

    campground.services.vault-agent.services.copyVPNcerts = {
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
                set -x
                cp /tmp/detsys-vault/copyVPNcerts.sh /home/mcamp/wtf

                # Create directory for VPN certificates
                mkdir -p /var/lib/vault/ovpn/

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

                # Generate Diffie-Hellman parameters
                ${pkgs.openssl}/bin/openssl dhparam -out /var/lib/vault/ovpn/dh.pem 2048

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
