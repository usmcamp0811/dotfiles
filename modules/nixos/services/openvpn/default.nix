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

    systemd.services.copyVPNcerts = {
      description = "Get VPN Server Certs from Vault";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/copyVPNcerts.sh";
        after = [ "vault-agent.service" ];
        before = [ "sssd.service" ];
      };
      wantedBy = [ "multi-user.target" ];
    };

    campground.services.vault-agent.services.copyLdapCAPem = {
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
            "server.crt" = {
              text = ''
              {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
              {{ .Data.certificate }}
              {{ end }}
              '';
              permissions = "0600";  # Make the script executable
              change-action = "restart";
            };
            "server.key" = {
              text = ''
              {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
              {{ .Data.private_key }}
              {{ end }}
              '';
              permissions = "0600";  # Make the script executable
              change-action = "restart";
            };
            "ca.crt" = {
              text = ''
              {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
              {{ .Data.issuing_ca }}
              {{ end }}
              '';
              permissions = "0600";  # Make the script executable
              change-action = "restart";
            };
          };
        };
      };
    };

  };
}
