{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.renew-pki;

  gen-server = pkgs.writeShellScriptBin "generate-server-pki" ''
    set -e
    SERVER_NAME=$1
    COMMON_NAME="vpn.server.${cfg.domain-name}"

    export VAULT_ADDR=${cfg.vault-address}

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

    echo "Writing vpn certificates files..."

    # Issue a new certificate and key pair, capturing the JSON output
    VAULT_OUTPUT=$(${pkgs.vault}/bin/vault write -format=json ${cfg.vault-path} common_name="$COMMON_NAME")

    SERIAL_NUMBER=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.serial_number')

    echo "Important: Save the following Serial Number. It is essential for future certificate renewals."
    echo "Serial Number: $SERIAL_NUMBER"

    # Parse the JSON to get the certificate, key, and issuing CA
    SERVER_CERT=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.certificate')
    SERVER_KEY=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.private_key')
    SERVER_CA=$(echo "$VAULT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.data.issuing_ca')

    # Write the values to their respective files
    echo "$SERVER_CERT" > server.crt
    echo "$SERVER_KEY" > server.key
    echo "$SERVER_CA" > ca.crt
  '';
in {
  options.fmf.services.renew-pki = with types; {
    # TODO: See if we can make the defaults come from elsewhere
    enable =
      mkBoolOpt false "Enable an AWS VPN Certificate Generation Service;";
    vpn-name = mkOpt str "vault" "VPN Name? might not be needed";
    cert-serial-nbr =
      mkOpt (listOf str) ["1234545678890"]
      "The Serial Numbers of the Certificates to Renew..";
    domain-name =
      mkOpt str "aicampground.com"
      "the domain name used in the PKI cert creation";
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "campground-pki/issue/vpn-server-role"
      "The Vault path to the Client Cert in Vault";
    vault-tls-path =
      mkOpt str "secret/campground/vpn"
      "The Vault path to the TLS Key in Vault";
    common-name =
      mkOpt str "vpn.${cfg.domain-name}" "Common Name for Server Certs";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [gen-server];

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
        # ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/copyVPNcerts.sh";
        after = ["vault-agent.service"];
        before = ["openvpn-fmf.service"];
      };
      script = ''
        # Generate the server certificate
        OVPN_DIR="/var/lib/vault/aws-vpn"
        VPN_NAME="${config.networking.hostName}_vpn"

        mkdir -p $OVPN_DIR
        cd $OVPN_DIR

        # vault write ata-pki/renew serial_number="XX:XX:XX:XX:XX:XX:XX:XX"


      '';
      wantedBy = ["multi-user.target"];
    };
  };
}
