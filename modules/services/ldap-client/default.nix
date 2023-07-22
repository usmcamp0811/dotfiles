{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.ldap-client;

in
{
  options.campground.services.ldap-client = with types; {
    enable = mkBoolOpt false "Whether or not to configure LDAP support.";
    domain = mkOpt str "aicampground" "The domain name.";
    ldap_uri = mkOpt str "ldap://ldap.campground.lan:389" "The ldap URI to use.";
    ldap_search_base = mkOpt str "dc=aicampground,dc=com" "The ldap search base.";
    cache_credentials = mkBoolOpt true "Whether or not to cache credentials.";
    role-id = mkOpt str "/var/lib/vault/sssd/role-id" "Absolute path to the Vault role-id";
    secret-id = mkOpt str "/var/lib/vault/sssd/secret-id" "Absolute path to the Vault secret-id";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    # NOTE! This is super duper important or else you wont be able to login as an LDAP user!!!! 
    system.activationScripts.binzsh = "ln -sf /run/current-system/sw/bin/zsh /usr/bin/zsh";
    environment.systemPackages = with pkgs; [
      sssd
      openldap
      openssl
    ];
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
ldap_tls_cacert = /tmp/detsys-vault/ldap_ca.pem  
entry_cache_timeout = 600
ldap_network_timeout = 2
ldap_schema = rfc2307
ldap_group_member = memberUid
    '';
    };

# TODO: see if i can remove the vault address and maybe the auth paths too
    campground.services.vault-agent.services.ssid = {
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
            "ldap_ca.pem" = {
              text = ''
                {{ with secret "secret/campground/ldap" }}
                {{ .Data.ldap_ca }}
                {{ end }}
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

