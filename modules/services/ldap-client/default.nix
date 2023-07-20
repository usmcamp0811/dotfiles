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

    environment.systemPackages = with pkgs; [
      sssd
      openldap
      openssl
    ];

    services.sssd = {
      enable = true;
      sshAuthorizedKeysIntegration = true;
      domains = [ {
        idProvider = "ldap";
        authProvider = "ldap";
        chpassProvider = "ldap";
        sudoProvider = "ldap";
        autofsProvider = "ldap";
        ldapUri = cfg.ldap_uri;
        ldapSearchBase = cfg.ldap_search_base;
        cacheCredentials = cfg.cache_credentials;
        minId = 100;
        ldapIdUseStartTls = true;
        ldapTlsReqcert = "allow";
        ldapTlsCacert = "/tmp/detsys-vault/ldap_ca.pem ";
        entryCacheTimeout = 600;
        ldapNetworkTimeout = 2;
        ldapSchema = "rfc2307";
        ldapGroupMember = "memberUid";
      } ];
    };
  };
}

