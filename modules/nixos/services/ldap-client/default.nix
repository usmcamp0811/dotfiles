{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.ldap-client;
  # This script fixes the problem I encountered using home-manager as a random LDAP user
  # LDAP users don't get `/nix/var/nix/profiles` created so we just watch /home
  # and if a new folder gets created (aka new user logs in) then we create the folder for them
  scriptPath = pkgs.writeShellScript "user-directory-watcher" ''
    ${pkgs.inotify-tools}/bin/inotifywait -m -e create --format '%f' /home | while read -r newUser
    do
      if [ -d "/home/$newUser" ]; then
        mkdir -p "/nix/var/nix/profiles/per-user/$newUser"
        chown $newUser:nixbld "/nix/var/nix/profiles/per-user/$newUser"
        echo "Created directory for new user: $newUser"
      fi
    done
  '';
in {
  options.fmf.services.ldap-client = with types; {
    enable = mkBoolOpt false "Whether or not to configure LDAP support.";
    domain = mkOpt str "aicampground" "The domain name.";
    ldap_uri =
      mkOpt str "ldap://ldap.fmf.lan:389" "The ldap URI to use.";
    ldap_search_base =
      mkOpt str "dc=aicampground,dc=com" "The ldap search base.";
    cache_credentials = mkBoolOpt true "Whether or not to cache credentials.";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-pki-path =
      mkOpt str "campground-pki/issue/ldap-server-role"
      "The Vault path to the Server Cert in Vault";
    common-name =
      mkOpt str "client.ldap.lan.aicampground.com"
      "Common Name for Server Certs";
    vault-path =
      mkOpt str "secret/campground/ldap"
      "The Vault path to the KV containing the LDAP Secrets.";
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    trusted_group =
      mkOpt str "ldap_user"
      "The LDAP Group of users who can user home-manager on the system.";
  };

  config = mkIf cfg.enable {
    # NOTE! This is super duper important or else you wont be able to login as an LDAP user!!!!
    system.activationScripts.binzsh = "ln -sf /run/current-system/sw/bin/zsh /usr/bin/zsh";
    environment.systemPackages = with pkgs; [
      sssd
      openldap
      openssl
      inotify-tools
    ];
    security.pam.services = {
      login.makeHomeDir = true;
      sshd.makeHomeDir = true;
      su.makeHomeDir = true;
    };

    # TODO: Test if this is needed... also is there a better place to put the tempated home dir?
    security.pam = {
      makeHomeDir = {skelDirectory = "/etc/skel";};
    };
    services.sssd = {
      enable = true;
      config = ''
        [sssd]
        config_file_version = 2
        services = nss, pam, ssh, sudo
        domains = default
        enumerate = true
        id_provider = ldap
        sudo_provider = ldap
        ldap_uri = ${cfg.ldap_uri}

        [domain/default]
        auth_provider = ldap
        chpass_provider = ldap
        cache_credentials = True
        debug_timestamps = True
        ldap_default_authtok_type = password
        ldap_search_base = ${cfg.ldap_search_base}
        ldap_sudo_search_base = ou=sudoers,${cfg.ldap_search_base}
        debug_level = 3
        min_id = 100
        ldap_uri = ${cfg.ldap_uri}

        id_provider = ldap
        sudo_provider = ldap
        autofs_provider = ldap
        ldap_id_use_start_tls = True
        ldap_tls_reqcert = allow
        ldap_tls_cacert = /var/lib/vault/ca.crt
        entry_cache_timeout = 600
        ldap_network_timeout = 2
        ldap_schema = rfc2307
        ldap_group_member = memberUid
      '';
    };
    systemd.services.sssd = {
      serviceConfig = {
        Restart = mkForce "always";
        RestartSec = "15s";
      };
      # wantedBy = [ "multi-user.target" "nscd.service" ];
      after = ["nscd.service" "sssd-after-dns.service"];
      requires = ["sssd-after-dns.service"];
    };

    systemd.services.sssd-after-dns = {
      requires = ["NetworkManager.service"];
      after = ["NetworkManager.service"];
      script = ''
        while ! grep -q '^nameserver' /etc/resolv.conf; do
          sleep 1;
        done
      '';
      serviceConfig.Type = "oneshot";
    };
    systemd.services.nscd = {
      wantedBy = ["multi-user.target"];
      partOf = ["sssd.service"];
      bindsTo = ["sssd.service"];
      after = ["nscd.service" "sssd-after-dns.service"];
      requires = ["sssd-after-dns.service"];
      restartTriggers = ["sssd.service"];
    };
    # Chad says this should let all ldap users in the `ldap_user` group to use home-manager
    nix.settings.trusted-users = ["@${cfg.trusted_group}"];

    systemd.services.userDirectoryWatcher = {
      description = "Watch for new user directories in /home because LDAP users seem to break home-manager.";
      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = "${scriptPath}";
      };
      wantedBy = ["multi-user.target"];
    };

    systemd.services.copyCAcert = mkIf config.fmf.services.vault-agent.enable {
      description = "Copy LDAP CA Cert somewhere to avoid SSSD shitting the bed randomly";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.coreutils}/bin/cp /tmp/detsys-vault/ca.crt /var/lib/vault/ca.crt";
      };
      wantedBy = ["nss-lookup.target"];
      # before = [ "nscd.service" ];
    };

    fmf.services.vault-agent.services.copyCAcert = {
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
            "ca.crt" = {
              text = ''
                {{ with secret "${cfg.vault-pki-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.issuing_ca }}
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
