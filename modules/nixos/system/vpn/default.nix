{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.vpn;

  gen-clients = pkgs.writeShellScriptBin "generate-client-ovpn" ''
    set -e

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

    seal_status=$(${pkgs.curl}/bin/curl -s "$VAULT_ADDR/v1/sys/seal-status" | ${pkgs.jq}/bin/jq ".sealed")

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
    # # TODO: Move this to the server cert
    # ROLE_EXISTS=$(${pkgs.vault}/bin/vault read -format=json ${cfg.vault-path} | ${pkgs.jq}/bin/jq -e .data > /dev/null 2>&1; echo $?)

    # # Check if the client role exists
    # if [ -z "$ROLE_EXISTS" ]; then
    #   echo "ROLE_EXISTS is empty, creating the client role."
    #   ${pkgs.vault}/bin/vault write ${cfg.vault-path} \
    #     allowed_domains="${cfg.domain-name}" \
    #     allow_subdomains="false" \
    #     max_ttl="336h" # 2 weeks
    #   echo "Client role ${cfg.vault-path} has been created."
    # elif [ "$ROLE_EXISTS" -ne 0 ]; then
    #   echo "Client role ${cfg.vault-path} already exists."
    # else
    #   echo "An unexpected condition occurred."
    # fi


    echo "Writing certificates..."

    # Fetch client certificate, key, and CA from Vault
    # Issue a new certificate and key pair, capturing the JSON output
    VAULT_OUTPUT=$(${pkgs.vault}/bin/vault write -format=json ${cfg.vault-path} common_name="$COMMON_NAME")

    # Parse the JSON to get the certificate and key
    CLIENT_CERT=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.certificate')
    CLIENT_KEY=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.private_key')

    TLS_KEY=$(${pkgs.vault}/bin/vault kv get -field=tls ${cfg.vault-tls-path})

    # Extract the serial number from the JSON output
    SERIAL_NUMBER=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.serial_number')

    # Append the serial number and common name
    # TODO: store this on the VPN server
    # TODO: Get the previous (not current or the one we are creating) serial number and invalidate it
    echo "$SERIAL_NUMBER,$COMMON_NAME"

    # Get the CA certificate
    CA_CERT=$(${pkgs.vault}/bin/vault read -field=certificate ${cfg.vault-ca-path})

    # Create .ovpn file
    cat > "''${CLIENT_NAME}.ovpn" <<EOL
    client
    dev tun
    proto udp
    remote ${cfg.vpn-server-address} ${cfg.vpn-port}
    resolv-retry infinite
    nobind
    remote-cert-tls server
    verb 3
    redirect-gateway def1
    resolv-retry infinite
    persist-key
    persist-tun
    cipher AES-256-GCM
    auth SHA512
    tls-client
    tls-version-min 1.2
    key-direction 1
    remote-cert-tls server
    <ca>
    $CA_CERT
    </ca>

    <cert>
    $CLIENT_CERT
    </cert>

    <key>
    $CLIENT_KEY
    </key>

    <tls-auth>
    $TLS_KEY
    </tls-auth>
    EOL

    echo "''${CLIENT_NAME}.ovpn file has been generated."
  '';
in {
  options.fmf.system.vpn = with types; {
    enable = mkBoolOpt false "Whether or not to enable VPN.";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "campground-pki/issue/vpn-client-role"
      "The Vault path to the Client Cert in Vault";
    vault-tls-path =
      mkOpt str "secret/campground/vpn"
      "The Vault path to the TLS Key in Vault";
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    common-name =
      mkOpt str "vpn.${cfg.domain-name}" "Common Name for Server Certs";
    domain-name = mkOpt str "aicampground.com" "Domain Name for Certs";
    vault-ca-path =
      mkOpt str "campground-pki/cert/ca"
      "The Vault path to the CA Cert in Vault";
    vpn-server-address =
      mkOpt str cfg.common-name "The public url or ip of the VPN server.";
    vpn-port = mkOpt str "1194" "The port used to connect to the VPN";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [gen-clients openvpn];

    systemd.timers.genVPNcert = {
      description = "Timer for Generate VPN Client Certs";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily"; # Runs every day at midnight
      };
      unitConfig = {PartOf = ["genVPNcert.service"];};
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
        VPN_NAME="${config.networking.hostName}"

        mkdir -p $OVPN_DIR
        cd $OVPN_DIR

        ${gen-clients}/bin/generate-client-ovpn ${config.networking.hostName}

        # Add the certificate to nmcli
        if ${pkgs.networkmanager}/bin/nmcli con show | grep -q $VPN_NAME; then
          ${pkgs.networkmanager}/bin/nmcli con delete id $VPN_NAME
        fi

        ${pkgs.networkmanager}/bin/nmcli con import type openvpn file $OVPN_FILE

        # Clean up
        # rm -rf $OVPN_FILE
      '';
      wantedBy = ["multi-user.target"];
    };
  };
}
