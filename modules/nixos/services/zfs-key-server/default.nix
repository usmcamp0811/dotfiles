{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.zfs-key-server;
  tangServersJSON = builtins.toJSON {
    t = cfg.threshold;
    pins = { tang = map (server: { url = server; }) cfg.tang-servers; };
  };
in {
  options.fmf.services.zfs-key-server = with types; {
    enable = mkBoolOpt false "Enable an Nginx Proxy;";
    port = mkOpt int 8084 "Port to Host the NGINX porxy on.";
    interface = mkOpt str "eno1" "Interface to use for the LAN Instance";
    lan-ip = mkOpt str "10.8.0.55" "IP to use for the LAN Instance";
    tang-servers = mkOption {
      type = listOf str;
      default = [ ];
      example = [ "http://10.8.0.140:1234" "http://10.8.0.127:1234" ];
      description = "List of Tang servers.";
    };
    threshold = mkOpt int 1 "Number of tanger serveres required to unlock";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/zfs"
      "The Vault path to the KV containing the LDAP Secrets.";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    fmf.services.keepalived = {
      enable = true;
      instances = {
        "zfs-key-server" = {
          interface = cfg.interface;
          ips = [ cfg.lan-ip ];
          state = "MASTER";
          priority = 50;
          virtualRouterId = 54;
        };
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."zfs-key-server" = {
        listen = [{
          addr = "0.0.0.0";
          port = cfg.port;
        }];
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
        ExecStart =
          "${pkgs.bash}/bin/bash /tmp/detsys-vault/save_encrypted_zfs_passphrase.sh";
        # ExecStart = "${pkgs.bash}/bin/bash /config/test.sh";
        after = [ "vault-agent.service" ];
        before = [ "nginx.service" ];
      };
      wantedBy = [ "multi-user.target" ];
      # TODO: Remove all but what is needed here
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
        gnugrep
      ];
    };
    fmf.services.vault-agent.services.encryptZFSkey = {
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
                mkdir -p /var/lib/vault/zfs-keys

                # Create directory if it doesn't exist
                mkdir -p /var/lib/vault/zfs-keys/

                # Perform Clevis encryption with SSS and store it in a file
                ${pkgs.clevis}/bin/clevis encrypt sss '${tangServersJSON}' -y <<< '{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.passphrase }}{{ else }}{{ .Data.data.passphrase }}{{ end }}{{ end }}' > /var/lib/vault/zfs-keys/zfs-keyfile

                # Change file owner to the user running Nginx
                chown nginx:nginx /var/lib/vault/zfs-keys/zfs-keyfile
              '';
              permissions = "0400"; # Make the script executable
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
