{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.openvpn;

  gen-clients = pkgs.writeShellScriptBin "generate-client-ovpn" ''
    set -e
    set -x

    CLIENT_NAME=$1
    COMMON_NAME="''${CLIENT_NAME}.client.${cfg.domain-name}"

    export VAULT_ADDR=${cfg.vault-address}

    if [ -z "$1" ]; then
      echo "Usage: $0 <client_name>"
      exit 1
    fi

    if ! [ -f '${cfg.role-id}' ]; then
      echo 'role-id file not found: ${cfg.role-id}'
      exit 1
    fi

    if ! [ -f '${cfg.secret-id}' ]; then
      echo 'secret-id file not found: ${cfg.secret-id}'
      exit 1
    fi

    seal_status=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | ${pkgs.jq}/bin/jq ".sealed")

    echo "Seal Status: $seal_status"

    if [ $seal_status = "true" ]; then
      echo "Vault is currently sealed, cannot generate client certificats."
      exit 1
    fi


    echo "Getting token..."

    token=$(${pkgs.vault}/bin/vault write -field=token auth/approle/login \
      role_id="$(cat ${cfg.role-id})" \
      secret_id="$(cat ${cfg.secret-id})" \
    ) || { echo "Failed to get token"; exit 1; }

    echo "Setting VAULT_TOKEN..."
    export VAULT_TOKEN="$token" || { echo "Failed to set VAULT_TOKEN"; exit 1; }

    # Check if the client role exists
    ROLE_EXISTS=$(${pkgs.vault}/bin/vault read -format=json ${cfg.vault-client-path} | ${pkgs.jq}/bin/jq -e .data > /dev/null 2>&1; echo $?)

    # Check if the client role exists
    if [ -z "$ROLE_EXISTS" ]; then
      echo "ROLE_EXISTS is empty, creating the client role."
      ${pkgs.vault}/bin/vault write ${cfg.vault-client-path} \
        allowed_domains="${cfg.domain-name}" \
        allow_subdomains="true" \
        max_ttl="72h"
      echo "Client role ${cfg.vault-client-path} has been created."
    elif [ "$ROLE_EXISTS" -ne 0 ]; then
      echo "Client role ${cfg.vault-client-path} already exists."
    else
      echo "An unexpected condition occurred."
    fi

    
    echo "Writing certificates..."

    # Fetch client certificate, key, and CA from Vault
    # Issue a new certificate and key pair, capturing the JSON output
    VAULT_OUTPUT=$(${pkgs.vault}/bin/vault write -format=json ${cfg.vault-client-path} common_name="$COMMON_NAME")

    # Parse the JSON to get the certificate and key
    CLIENT_CERT=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.certificate')
    CLIENT_KEY=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.private_key')

    # Get the CA certificate
    CA_CERT=$(${pkgs.vault}/bin/vault read -field=certificate ${cfg.vault-ca-path})

    # Create .ovpn file
    cat > "''${CLIENT_NAME}.ovpn" <<EOL
    client
    dev tun
    proto udp
    remote vpn.aicampground.com 1194
    remote-random-hostname
    resolv-retry infinite
    nobind
    remote-cert-tls server
    cipher AES-256-CBC
    verb 3
    redirect-gateway def1

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
    vault-path = mkOpt str "pki/issue/campground-vpn-server-role" "The Vault path to the Server Cert in Vault";
    vault-client-path = mkOpt str "pki/issue/campground-vpn-client-role" "The Vault path to the Client Cert in Vault"; 
    vault-ca-path = mkOpt str "pki/cert/ca" "The Vault path to the CA Cert in Vault"; 
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    common-name = mkOpt str "vpn.${cfg.domain-name}" "Common Name for Server Certs";
    domain-name = mkOpt str "aicampground.com" "Domain Name for Certs";
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
