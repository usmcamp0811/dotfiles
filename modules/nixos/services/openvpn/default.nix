{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.openvpn;
  gen-server = pkgs.writeShellScriptBin "generate-server-ovpn" ''
    set -e

    SERVER_NAME=$1
    COMMON_NAME="server.vpn.${cfg.domain-name}"

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

    seal_status=$(${pkgs.curl}/bin/curl -s "$VAULT_ADDR/v1/sys/seal-status" | ${pkgs.jq}/bin/jq ".sealed")

    echo "Seal Status: $seal_status"

    if [ $seal_status = "true" ]; then
      echo "Vault is currently sealed, cannot generate server certificats."
      exit 1
    fi


    echo "Getting token..."

    token=$(${pkgs.vault}/bin/vault write -field=token auth/approle/login \
      role_id="$(cat ${cfg.role-id})" \
      secret_id="$(cat ${cfg.secret-id})" \
    ) || { echo "Failed to get token"; exit 1; }

    echo "Setting VAULT_TOKEN..."
    export VAULT_TOKEN="$token" || { echo "Failed to set VAULT_TOKEN"; exit 1; }

    echo "Writing certificates..."

    # Fetch client certificate, key, and CA from Vault
    # Issue a new certificate and key pair, capturing the JSON output
    VAULT_OUTPUT=$(${pkgs.vault}/bin/vault write -format=json ${cfg.vault-path} common_name="$COMMON_NAME")

    # Parse the JSON to get the certificate and key
    SERVER_CERT=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.certificate')
    SERVER_KEY=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.private_key')

    TLS_KEY=$(${pkgs.vault}/bin/vault kv get -field=tls ${cfg.vault-tls-path})

    # Extract the serial number from the JSON output
    SERIAL_NUMBER=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.serial_number')

    # Get the CA certificate
    CA_CERT=$(${pkgs.vault}/bin/vault read -field=certificate ${cfg.vault-ca-path})

    mkdir -p /var/lib/vault/ovpn/server/

    # generate diffie-hellman parameters
    ${pkgs.openssl}/bin/openssl dhparam -out /var/lib/vault/ovpn/dh.pem 2048

    echo "$CA_CERT" > /var/lib/vault/ovpn/ca.crt
    echo "$SERVER_CERT" > /var/lib/vault/ovpn/server.crt
    echo "$SERVER_KEY" > /var/lib/vault/ovpn/server.key
  '';
in {
  # TODO: clean up any unused options
  options.fmf.services.openvpn = with types; {
    enable = mkBoolOpt false "Enable OpenVPN Server;";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "campground-pki/issue/vpn-server-role"
      "The Vault path to the Server Cert in Vault";
    vault-client-path =
      mkOpt str "campground-pki/issue/vpn-client-role"
      "The Vault path to the Client Cert in Vault";
    vault-ca-path =
      mkOpt str "campground-pki/cert/ca"
      "The Vault path to the CA Cert in Vault";
    vault-tls-path =
      mkOpt str "secret/campground/vpn"
      "The Vault path to the TLS Key in Vault";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version used for tls key";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    common-name =
      mkOpt str "server.vpn.${cfg.domain-name}" "Common Name for Server Certs";
    domain-name = mkOpt str "aicampground.com" "Domain Name for Certs";
    vpn-cert-csv =
      mkOpt str "/var/lib/vault/ovpn/vpn-certs.csv"
      "CSV with Cert Serial Numbers";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [gen-server openvpn];
    users.users.ovpn = {
      isSystemUser = true;
      group = "ovpn";
      description = "OpenVPN service user";
    };

    users.groups.ovpn = {};

    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    networking.nat = {
      enable = true;
      externalInterface = "eth0";
      internalInterfaces = ["tun0"];
    };

    networking.firewall.allowedUDPPorts = [1194];

    services.openvpn.servers = {
      fmf = {
        config = ''
          port 1194
          proto udp
          dev tun
          ca /var/lib/vault/ovpn/ca.crt
          cert /var/lib/vault/ovpn/server.crt
          key /var/lib/vault/ovpn/server.key
          dh /var/lib/vault/ovpn/dh.pem
          ifconfig-pool-persist ipp.txt
          keepalive 10 120
          cipher AES-256-GCM
          ncp-ciphers AES-256-GCM:AES-256-CBC
          topology subnet
          auth SHA512
          persist-key
          persist-tun
          status openvpn-status.log
          verb 1
          tls-server
          tls-version-min 1.2
          tls-auth /var/lib/vault/ovpn/ta.key 0
          server 10.8.1.0 255.255.255.0
          push "redirect-gateway def1 bypass-dhcp"
          push "route 10.8.1.0 255.255.255.0"
          push "dhcp-option DNS 8.8.8.8"
          push "dhcp-option DNS 8.8.4.4"
        '';
      };
    };

    # TODO: Refactor so that this just renews the server cert
    # TODO: Refactor to make the `copyVPNcerts.sh` script is installed and can be run independent of the systmed service
    # TODO: Clean up or otherwise just make things look better and more uniform
    # TODO: Add OpenVPN Admin: https://github.com/flant/ovpn-admin
    # Probably just make it a package.. looks simple enough
    systemd.timers.genVPNserver-cert = {
      description = "Timer for Generate VPN Client Certs";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily"; # Runs every day at midnight
      };
      unitConfig = {PartOf = ["genVPNserver-cert.service"];};
    };

    systemd.services.genVPNserver-cert = {
      description = "Get VPN Server Certs from Vault";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/copyVPNcerts.sh";
        after = ["vault-agent.service"];
        before = ["openvpn-fmf.service"];
      };
      wantedBy = ["multi-user.target"];
    };
    # TODO: Refactor this so that we rotate server certs in a similar manner as the client certs
    fmf.services.vault-agent.services.genVPNserver-cert = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
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

                # Generate tls-auth key
                # generate it like this ->  openvpn --genkey secret /var/lib/vault/ovpn/ta.key and put in the vault

                cat <<EOL > /var/lib/vault/ovpn/ta.key
                {{ with secret "${cfg.vault-tls-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.tls }}{{ else }}{{ .Data.data.tls }}{{ end }}{{ end }}
                EOL

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
