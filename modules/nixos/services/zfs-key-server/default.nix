{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.zfs-key-server;
  tangServersJSON = builtins.toJSON (map (server: { url = server; }) cfg.tang-servers);

in
{
  options.campground.services.zfs-key-server = with types; {
    enable = mkBoolOpt false "Enable an Nginx Proxy;";
    port = mkOpt int 8080 "Port to Host the NGINX porxy on.";
    tang-servers = mkOption {
      type = listOf str;
      default = [ ];
      example = [ "http://10.8.0.140:1234" "http://10.8.0.127:1234" ];
      description = "List of Tang servers.";
    };
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
          alias /var/lib/vault/zfs-keys/;
          autoindex off;
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
        # ExecStart = "${pkgs.bash}/bin/bash /config/test.sh";
        after = [ "vault-agent.service" ];
        before = [ "nginx.service" ];
      };
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        ncurses
        python3
        cairo
        freetype
        bzip2
        brotli
        fontconfig
        expat
        clevis
        glib
        gettext
        attr
        curl
        clevis
      ];

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
                $SHELL
                set -e  # exit immediately on error
                set -x
                mkdir -p /var/lib/vault/zfs-keys

                ZFS_PASSPHRASE='{{ with secret "${cfg.vault-path}" }}{{ .Data.passphrase }}{{ end }}'

                # Create directory if it doesn't exist
                mkdir -p /var/lib/vault/zfs-keys/
                env
                ${pkgs.curl}/bin/curl http://webb:1234/adv
                ${pkgs.curl}/bin/curl http://lucas:1234/adv
                ${pkgs.curl}/bin/curl http://ermy:1234/adv
                # Perform Clevis encryption with SSS and store it in a file
                ${pkgs.clevis}/bin/clevis encrypt sss '{"t":1,"pins":{"tang":[{"url":"http://webb:1234"},{"url":"http://lucas:1234"},{"url":"http://ermy:1234"}]}}' -y <<< $ZFS_PASSPHRASE > /var/lib/vault/zfs-keys/zfs-keyfile

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
