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
    vault-path = mkOpt str "campground-pki/issue/vpn-server-role" "The Vault path to the Server Cert in Vault";
    vault-client-path = mkOpt str "campground-pki/issue/vpn-client-role" "The Vault path to the Client Cert in Vault"; 
    vault-ca-path = mkOpt str "campground-pki/cert/ca" "The Vault path to the CA Cert in Vault"; 
    vault-tls-path = mkOpt str "secret/campground/vpn" "The Vault path to the TLS Key in Vault"; 
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
    common-name = mkOpt str "server.vpn.${cfg.domain-name}" "Common Name for Server Certs";
    domain-name = mkOpt str "aicampground.com" "Domain Name for Certs";
    vpn-cert-csv = mkOpt str "/var/lib/vault/ovpn/vpn-certs.csv" "CSV with Cert Serial Numbers";
  };

  config = mkIf cfg.enable {
    networking.wireguard.enable = true;
    networking.wireguard.interfaces."wg0" = {
     privateKeyFile = "/var/lib/wireguard/wg0-priv-key";
     ips = [ "10.10.10.1/24" "fc10:10:10::1/64" ];
     listenPort = 1194;
     peers = [                                                                                                                                                                                                                        
       { publicKey = "XnBofROntu+DYUaGC8VK6t8SRpKoYuQ6GjDSZNmFME4=";
         allowedIPs = [ "10.10.10.2/32" "fc10:10:10::2/128" ]; }
     ];
    };
# TODO: Refactor this so that we rotate server certs in a similar manner as the client certs
    # campground.services.vault-agent.services.genVPNserver-cert = {
    #   settings = {
    #     vault.address = cfg.vault-address;
    #     auto_auth = {
    #       method = [{
    #         type = "approle";
    #         config = {
    #           role_id_file_path = cfg.role-id;
    #           secret_id_file_path = cfg.secret-id;
    #           remove_secret_id_file_after_reading = false;
    #         };
    #       }];
    #     };
    #   };
    #   secrets = {
    #     file = {
    #       files = {
    #         "copyVPNcerts.sh" = {
    #           text = ''
    #             #!/bin/sh
    #             set -e  # exit immediately on error
    #
    #             # Create directory for VPN certificates
    #             mkdir -p /var/lib/vault/ovpn/
    #
    #             # Create directory for client certificates
    #             mkdir -p /var/lib/vault/ovpn/clients/
    #
    #             # Generate server.crt
    #             cat <<EOL > /var/lib/vault/ovpn/server.crt
    #             {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
    #             {{ .Data.certificate }}
    #             {{ end }}
    #             EOL
    #
    #             # Generate server.key
    #             cat <<EOL > /var/lib/vault/ovpn/server.key
    #             {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
    #             {{ .Data.private_key }}
    #             {{ end }}
    #             EOL
    #
    #             # Generate ca.crt
    #             cat <<EOL > /var/lib/vault/ovpn/ca.crt
    #             {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
    #             {{ .Data.issuing_ca }}
    #             {{ end }}
    #             EOL
    #
    #             # # Generate Diffie-Hellman parameters
    #             # ${pkgs.openssl}/bin/openssl dhparam -out /var/lib/vault/ovpn/dh.pem 2048
    #
    #             # Generate tls-auth key
    #             # generate it like this ->  openvpn --genkey secret /var/lib/vault/ovpn/ta.key and put in the vault
    #
    #             cat <<EOL > /var/lib/vault/ovpn/ta.key
    #             {{ with secret "${cfg.vault-tls-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.tls }}{{ else }}{{ .Data.data.tls }}{{ end }}{{ end }}
    #             EOL
    #
    #             # Fix permissions
    #             chown -R ovpn:ovpn /var/lib/vault/ovpn/*
    #             chmod -R 0600 /var/lib/vault/ovpn
    #           '';
    #           permissions = "0400";
    #           change-action = "restart";
    #         };
    #       };
    #     };
    #   };
    # };
  };
}
