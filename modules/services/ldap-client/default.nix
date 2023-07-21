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
  };
}

