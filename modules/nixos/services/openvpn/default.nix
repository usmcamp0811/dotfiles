{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.openvpn;

  gen-clients = pkgs.writeShellScriptBin "generate-client-ovpn" ''
    #!/usr/bin/env bash

    if [ -z "$1" ]; then
      echo "Usage: $0 <client_name>"
      exit 1
    fi

    CLIENT_NAME=$1
    COMMON_NAME="''${CLIENT_NAME}.client.aicampground.com"

    # Fetch client certificate, key, and CA from Vault
    CLIENT_CERT=$(${pkgs.vault}/bin/vault write -field=certificate pki/issue/campground-vpn-client-role common_name="$COMMON_NAME")
    CLIENT_KEY=$(${pkgs.vault}/bin/vault write -field=private_key pki/issue/campground-vpn-client-role common_name="$COMMON_NAME")
    CA_CERT=$(${pkgs.vault}/bin/vault read -field=certificate pki/cert/ca)

    # Create .ovpn file
    cat > "''${CLIENT_NAME}.ovpn" <<EOL
    client
    dev tun
    proto udp
    remote vpn.aicampground.com 1194
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    remote-cert-tls server
    auth-nocache
    cipher AES-256-CBC
    verb 3

    <ca>
    $CA_CERT
    </ca>

    <cert>
    $CLIENT_CERT
    </cert>

    <key>
    $CLIENT_KEY
    </key>
    EOL

    echo "''${CLIENT_NAME}.ovpn file has been generated."
  '';
in
{
  options.campground.services.openvpn = with types; {
    enable = mkBoolOpt false "Enable OpenVPN Server;";
    clients = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of OpenVPN clients.";
    };
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
      gen-clients
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

    systemd.services.genVPNclients = {
      description = "Generate VPN Client Certs";
      environment.CLIENTS = builtins.concatStringsSep " " config.campground.services.openvpn.clients;
      # WorkingDirectory = "/var/lib/vault/ovpn/clients";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c 'mkdir -p /var/lib/vault/ovpn/clients && cd /var/lib/vault/ovpn/clients && for client in $CLIENTS; do ${gen-clients}/bin/generate-client-ovpn $client; done'
        '';
        after =  [ "copyVPNcerts.service" ];
        before = [ "openvpn-campground.service" ];
      };
      wantedBy = [ "multi-user.target" ];
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
