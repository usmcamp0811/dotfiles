{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.system.vpn;

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

    # Extract the serial number from the JSON output
    SERIAL_NUMBER=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.serial_number')

    # Append the serial number and common name to the CSV file
    echo "$SERIAL_NUMBER,$COMMON_NAME" >> ${cfg.vpn-cert-csv}

    # Get the CA certificate
    CA_CERT=$(${pkgs.vault}/bin/vault read -field=certificate ${cfg.vault-ca-path})

    # Create .ovpn file
    cat > "''${CLIENT_NAME}.ovpn" <<EOL
    client
    dev tun
    proto udp
    remote ${cfg.common-name} 1194
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
  options.campground.system.vpn = with types; {
    enable = mkBoolOpt false "Whether or not to enable VPN.";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/vpn" "The Vault path to the KV containing the VPN Secrets.";
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

    systemd.timers.genVPNcert = {
      description = "Timer for Generate VPN Client Certs";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily"; # Runs every day at midnight
      };
      unitConfig = {
        PartOf = [ "genVPNcert.service" ];
      };
    };

    systemd.services.genVPNcert = {
      description = "Generate VPN Client Cert";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        WorkingDirectory = "/var/lib/vault/${config.networking.hostName}/";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c '${gen-clients}/bin/generate-client-ovpn ${config.networking.hostName}'
        '';
      };
      wantedBy = [ "multi-user.target" ];
    };
    systemd.services.genVPNcert = {
      description = "Generate VPN Client Cert and Add to nmcli";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        # Generate the client certificate
        OVPN_DIR="/var/lib/vault/${config.networking.hostName}"
        OVPN_FILE="$OVPN_DIR/${config.networking.hostName}.ovpn"
        VPN_NAME="${config.networking.hostName}_vpn"

        mkdir -p $OVPN_DIR
        cd $OVPN_DIR

        ${pkgs.bash}/bin/bash -c '${gen-clients}/bin/generate-client-ovpn ${config.networking.hostName}'

        # Add the certificate to nmcli
        if ${pkgs.networkmanager}/bin/nmcli con show | grep -q $VPN_NAME; then
          ${pkgs.networkmanager}/bin/nmcli con delete id $VPN_NAME
        fi

        ${pkgs.networkmanager}/bin/nmcli con import type openvpn file $OVPN_FILE

        # Clean up
        rm -rf $OVPN_FILE
      '';
      wantedBy = [ "multi-user.target" ];
    };
  };
}
