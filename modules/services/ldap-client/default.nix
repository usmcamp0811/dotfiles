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
    authorizedKeys =
      mkOpt (listOf str) [ default-key ] "The public keys to apply.";
    port = mkOpt port 2222 "The port to listen on (in addition to 22).";
    manage-other-hosts = mkOpt bool true "Whether or not to add other host configurations to SSH config.";
  };

  # TODO: use variables down here
  config = mkIf cfg.enable {
    # is this where this goes? feel like it needs to be modified
    environment.systemPackages = with pkgs; [
      sssd
      openldap
      openssl
    ];
    services.sssd.enable = true;

    services.sssd.config = {
      sssd = {
        services = [ "nss" "pam" ];
        domains = [ "aicampground" ];
      };

      domain/aicampground = {
        id_provider = "ldap";
        ldap_uri = "ldap://ldap.campground.lan:389";
        ldap_search_base = "dc=aicampground,dc=com";
        ldap_tls_reqcert = "never";
        cache_credentials = true;
        enumerate = true;
        use_fully_qualified_names = false;
      };
    };
  };
}
