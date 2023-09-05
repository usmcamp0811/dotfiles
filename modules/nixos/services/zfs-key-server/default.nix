{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.zfs-key-server;
  tangServersJSON = builtins.toJSON (lib.concatMapStrings (server: { url = server; }) cfg.tang-servers);
in
{
  options.campground.services.cac = with types; {
    enable = mkBoolOpt false "Enable an Nginx Proxy;";
    port = mkOpt int 8080 "Port to Host the NGINX porxy on.";
    tang-servers = mkOpt listOf str [] "List of Tang Servers";

    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/zfs" "The Vault path to the KV containing the LDAP Secrets.";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };

  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts."zfs-key-server" = {
        listen = [ { addr = "0.0.0.0"; port = cfg.port; } ];
        locations."/".extraConfig = ''
          alias /root/hdd-keys/;
          autoindex on;
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.services.encryptZFSkey = {
      description = "Get ZFS Passphrase from Vault and Encrypt with Clevis";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/save_encrypted_zfs_passphrase.sh";
        after = [ "vault-agent.service" ];
        before = [ "nginx.service" ];
      };
      wantedBy = [ "multi-user.target" ];
    };

    campground.services.vault-agent.services.encryptZFSkey = {
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
            "save_encrypted_zfs_passphrase.sh" = {
              text = ''
                #!/bin/sh
                set -e  # exit immediately on error
                mkdir -p /var/lib/vault/zfs-keys
                ZFS_PASSPHRASE='{{ with secret "${cfg.vault-path}" }}{{ .Data.passphrase }}{{ end }}'

                # Create directory if it doesn't exist
                mkdir -p /var/lib/vault/zfs-keys/

                # Perform Clevis encryption with SSS and store it in a file
                ${pkg.clevis}/bin/clevis encrypt sss \
                  '{"t":1,"pins":{"tang":${tangServersJSON}}}' \
                  <<< "$ZFS_PASSPHRASE" > /var/lib/vault/zfs-keys/zfs-keyfile

                # Change file owner to the user running Nginx
                chown nginx:nginx /var/lib/vault/zfs-keys/zfs-keyfile
              '';
              permissions = "0400";  # Make the script executable
              change-action = "restart";
            };
          };
        };
      };
    };

  };
}
