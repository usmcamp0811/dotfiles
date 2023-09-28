{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.ldap-server;

  module-ldif = pkgs.writeText "module.ldif" ''
    dn: cn=module,cn=config
    cn: module
    objectClass: olcModuleList
    olcModuleLoad: memberof
    olcModulePath: /usr/lib/ldap
  '';

  memberof-ldif = pkgs.writeText "memberof.ldif" ''
    dn: olcOverlay={0}memberof,olcDatabase={1}hdb,cn=config
    objectClass: olcConfig
    objectClass: olcMemberOf
    objectClass: olcOverlayConfig
    objectClass: top
    olcOverlay: memberof
    olcMemberOfDangling: ignore
    olcMemberOfRefInt: TRUE
    olcMemberOfGroupOC: groupOfNames
    olcMemberOfMemberAD: member
    olcMemberOfMemberOfAD: memberOf
  '';

  refint-ldif = pkgs.writeText "refint.ldif" ''
    dn: cn=module{1},cn=config
    add: olcmoduleload
    olcmoduleload: refint

    dn: olcOverlay={1}refint,olcDatabase={1}hdb,cn=config
    objectClass: olcConfig
    objectClass: olcOverlayConfig
    objectClass: olcRefintConfig
    objectClass: top
    olcOverlay: {1}refint
    olcRefintAttribute: memberof member manager owner
  '';

  openssh-ldif = pkgs.writeText "openssh.ldif" ''
    dn: cn=openssh-lpk,cn=schema,cn=config
    objectClass: olcSchemaConfig
    cn: openssh-lpk
  '';

  sudo-ldif = pkgs.writeText "sudo.ldif" ''
    dn: cn=sudo,cn=schema,cn=config
    objectClass: olcSchemaConfig
    cn: sudo
    olcAttributeTypes: {0}( 1.3.6.1.4.1.15953.9.1.1 NAME 'sudoUser' DESC 'User(s) who may  run sudo' EQUALITY caseExactIA5Match SUBSTR caseExactIA5SubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
    olcAttributeTypes: {1}( 1.3.6.1.4.1.15953.9.1.2 NAME 'sudoHost' DESC 'Host(s) who may run sudo' EQUALITY caseExactIA5Match SUBSTR caseExactIA5SubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
    olcAttributeTypes: {2}( 1.3.6.1.4.1.15953.9.1.3 NAME 'sudoCommand' DESC 'Command(s) to be executed by sudo' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
    olcAttributeTypes: {3}( 1.3.6.1.4.1.15953.9.1.4 NAME 'sudoRunAs' DESC 'User(s) impersonated by sudo (deprecated)' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
    olcAttributeTypes: {4}( 1.3.6.1.4.1.15953.9.1.5 NAME 'sudoOption' DESC 'Options(s) followed by sudo' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
    olcAttributeTypes: {5}( 1.3.6.1.4.1.15953.9.1.6 NAME 'sudoRunAsUser' DESC 'User(s) impersonated by sudo' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
    olcAttributeTypes: {6}( 1.3.6.1.4.1.15953.9.1.7 NAME 'sudoRunAsGroup' DESC 'Group(s) impersonated by sudo' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
    olcAttributeTypes: {7}( 1.3.6.1.4.1.15953.9.1.8 NAME 'sudoNotBefore' DESC 'Start of time interval for which the entry is valid' EQUALITY generalizedTimeMatch ORDERING generalizedTimeOrderingMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.24 )
    olcAttributeTypes: {8}( 1.3.6.1.4.1.15953.9.1.9 NAME 'sudoNotAfter' DESC 'End of time interval for which the entry is valid' EQUALITY generalizedTimeMatch ORDERING generalizedTimeOrderingMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.24 )
    olcAttributeTypes: {9}( 1.3.6.1.4.1.15953.9.1.10 NAME 'sudoOrder' DESC 'an integer to order the sudoRole entries' EQUALITY integerMatch ORDERING integerOrderingMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.27 )
    olcObjectClasses: {0}( 1.3.6.1.4.1.15953.9.2.1 NAME 'sudoRole' DESC 'Sudoer Entries' SUP top STRUCTURAL MUST cn MAY ( sudoUser $ sudoHost $ sudoCommand $ sudoRunAs $ sudoRunAsUser $ sudoRunAsGroup $ sudoOption $ sudoOrder $ sudoNotBefore $ sudoNotAfter $ description ) )
  '';

  pp-ldif = pkgs.writeText "pp.ldif" ''
    #load password policy module
    dn: cn=module{0},cn=config
    changetype: modify
    add: olcModuleLoad
    olcModuleLoad: {0}ppolicy

    #configure password policy module
    dn: olcOverlay=ppolicy,olcDatabase={1}${ldapBackend},cn=config
    changetype: add
    objectClass: olcPPolicyConfig
    objectClass: olcOverlayConfig
    olcOverlay: ppolicy
    olcPPolicyDefault: cn=default,ou=pwpolicies,${ldapBaseDN}
    olcPPolicyHashCleartext: TRUE
    olcPPolicyUseLockout: TRUE
  '';
in
{
  options.campground.services.ldap-server = with types; {
    enable = mkBoolOpt false "Enable Docker;";
    ldapBackend = mkOpt str "??Look at jinja docker things" "the Ldap Backend";
    ldapBaseDN = mkOpt str "Look at jinja" "The BaseDN";
    domain-name = mkOpt str "aicampground" "The domain name to use";
    rootdn = mkOpt str "cn=admin,dc=${cfg.domain-name},dc=com" "The Root DN to use";
    suffix = mkOpt str "dc=${cfg.domain-name},dc=com" "The suffix";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 389 8080 ]; # OpenLDAP and phpLDAPadmin ports

    services.openldap = {
      enable = true;
      rootdn = "cn=admin,${ldapBaseDN}";
      rootpw = "{CLEARTEXT}admin"; # Use a more secure method in production
      extraDatabaseConfig = {
        mdb = {
          suffix = ldapBaseDN;
        };
      };
      ldif = pp-ldif;
    };

    services.httpd = {
      enable = true;
      adminAddr = "admin@aicampground.com";
      ports = [
        { port = 8080; }
      ];
      extraModules = [
        { name = "proxy"; path = "${pkgs.apacheHttpd}/modules/mod_proxy.so"; }
        { name = "proxy_fcgi"; path = "${pkgs.apacheHttpd}/modules/mod_proxy_fcgi.so"; }
      ];
      virtualHosts = [
        {
          hostName = "localhost";
          documentRoot = "${pkgs.phpLDAPadmin}/share/phpldapadmin/htdocs";
          extraConfig = ''
            <Directory "${pkgs.phpLDAPadmin}/share/phpldapadmin/htdocs">
              DirectoryIndex index.php
              Require all granted
            </Directory>
          '';
        }
      ];
    };

    services.phpfpm.pools.phpldapadmin = {
      user = "httpd";
      settings = {
        "listen.owner" = "httpd";
        "listen.group" = "httpd";
      };
    };
  };
}
