{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.ldap-client;

in
{
  # TODO: modify this to have all the options for LDAP
  options.campground.services.ldap-client = with types; {
    enable = mkBoolOpt false "Whether or not to configure LDAP support.";
    domain = mkOpt str "aicampground" "The domain name.";
    ldap_uri = mkOpt str "ldap://ldap.campground.lan:389" "The ldap URI to use.";
    ldap_search_base = mkOpt str "dc=aicampground,dc=com" "The ldap search base.";
    cache_credentials = mkBoolOpt true "Wheather or not to cache credentials.";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      sssd
      openldap
      openssl
    ];

    services.sssd.enable = true;
    services.sssd.sshAuthorizedKeysIntegration = true;
    services.sssd.environmentFile = ./sssd.conf
  };
}
