{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.ldap-server;

  user-template =
    pkgs.writeText "user-template.xml"
    (builtins.readFile ./openldap/user-template.xml);
  entrypoint = pkgs.writeText "run" (builtins.readFile ./openldap/run);

  inherit (pkgs.fmf) phpLDAPadmin;
in {
  options.fmf.services.ldap-server = with types; {
    enable = mkBoolOpt false "Enable Docker;";
    ldapBackend = mkOpt str "mdb" "the Ldap Backend";
    domain-name = mkOpt str "aicampground" "The domain name to use";
    ldapBaseDN = mkOpt str "dc=${cfg.domain-name},dc=com" "The BaseDN";
    rootdn =
      mkOpt str "cn=admin,dc=${cfg.domain-name},dc=com" "The Root DN to use";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-pki-path =
      mkOpt str "campground-pki/issue/ldap-server-role"
      "The Vault path to the Server Cert in Vault";
    vault-path =
      mkOpt str "secret/campground/ldap"
      "The Vault path to the KV containing the LDAP Secrets.";
    common-name =
      mkOpt str "server.ldap.lan.aicampground.com"
      "Common Name for Server Certs";
    ldap_uri =
      mkOpt str "ldap://ldap.fmf.lan"
      "The url of hte server.. should be the hostname or ip or dns name";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
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
    networking.firewall.allowedTCPPorts = [389 636 8080 8081]; # OpenLDAP and phpLDAPadmin ports

    system.activationScripts.copyLdapFiles = {
      text = ''
        mkdir -p /var/lib/ldap
        cp ${user-template} /var/lib/ldap/customUser.xml
        cp ${entrypoint} /var/lib/ldap/run
        chmod 777 /var/lib/ldap/customUser.xml
        chmod 777 /var/lib/ldap/run
      '';
    };

    virtualisation.oci-containers.containers = {
      phpldapadmin = {
        # image = "docker.io/osixia/phplpdapadmin:latest";
        # some stupid shit is going on with podman not getting the image.. need to hurry up making my phpldapadmin config thing  below
        image = "dbb580facde30c5698bdc8945399de0709b75a5606182180f1d3da991c6c356d";
        ports = ["8080:80"];
        environment = {
          PHPLDAPADMIN_LDAP_HOSTS = "${cfg.ldap_uri}"; # Replace with your LDAP server address
          PHPLDAPADMIN_HTTPS = "false";
        };
        volumes = [
          "/var/lib/ldap/customUser.xml:/templates/customUser.xml"
          "/var/lib/ldap/run:/container/tool/run"
          # "/tmp/detsys-vault/ca.crt:/container/service/phpldapadmin/assets/certs/ca.crt"
        ];
      };
    };
    environment.systemPackages = [phpLDAPadmin];

    # TODO: Move to nix package over oci-contianer for phpldapadmin
    # services.nginx = {
    #   enable = true;
    #   virtualHosts."phpLDAPadmin" = {
    #     listen = [
    #       { addr = "0.0.0.0"; port = 8080; }
    #       { addr = "::"; port = 8080; }
    #     ];
    #     root = "/var/www/phpLDAPadmin";
    #     locations."~ \.php$".extraConfig = ''
    #       fastcgi_pass unix:${config.services.phpfpm.pools.phpLDAPadmin.socket};
    #       include ${pkgs.nginx}/conf/fastcgi_params;
    #       fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    #     '';
    #   };
    # };
    #
    # services.phpfpm.pools = {
    #   phpLDAPadmin = {
    #     user = "nginx";
    #     group = "nginx";
    #     settings = {
    #       "pm" = "dynamic";
    #       "pm.max_children" = 5;
    #       "pm.start_servers" = 2;  # Number of servers to start
    #       "pm.min_spare_servers" = 1;  # Minimum number of idle servers
    #       "pm.max_spare_servers" = 3;  # Maximum number of idle servers
    #       "listen.owner" = "nginx";
    #       "listen.group" = "nginx";
    #     };
    #   };
    # };

    services.openldap = {
      enable = true;
      # NOTE: If you make changes to the schema and have `mutableConfig = true` the schema will not update most likely.
      # mutableConfig = true;
      settings.attrs = {
        olcLogLevel = "conns config";
        # settings for acme ssl
        olcTLSCACertificateFile = "/tmp/detsys-vault/ca.crt";
        olcTLSCertificateFile = "/tmp/detsys-vault/ldap.crt";
        olcTLSCertificateKeyFile = "/tmp/detsys-vault/ldap.key";
        olcTLSCipherSuite = "HIGH:MEDIUM:+3DES:+RC4:+aNULL";
        olcTLSCRLCheck = "none";
        olcTLSVerifyClient = "never";
        olcTLSProtocolMin = "3.1";
      };

      # settings.attrs.olcLogLevel = "0";

      # enable plain and secure connections
      urlList = ["ldap:///" "ldaps:///"];

      settings.children = {
        "cn=schema".includes = [
          "${pkgs.openldap}/etc/schema/core.ldif"
          "${pkgs.openldap}/etc/schema/cosine.ldif"
          "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
          "${pkgs.openldap}/etc/schema/nis.ldif"
        ];
        "olcDatabase={1}mdb".attrs = {
          objectClass = ["olcDatabaseConfig" "olcMdbConfig"];
          olcDatabase = "{1}mdb";
          olcDbDirectory = "/var/lib/openldap/data";
          olcRootPW.path = "/tmp/detsys-vault/olcRootPW.secret";
          olcRootDN = "cn=admin,${cfg.ldapBaseDN}";
          olcSuffix = cfg.ldapBaseDN;
          olcAccess = [
            ''
              {0}to attrs=userPassword
                               by self write  by anonymous auth
                               by dn.base="cn=dovecot,dc=mail,${cfg.ldapBaseDN}" read
                               by dn.base="cn=gitlab,ou=system,ou=users,${cfg.ldapBaseDN}" read
                               by dn.base="cn=ldapsync,ou=system,ou=users,${cfg.ldapBaseDN}"
                               read by * none''
            "{1}to attrs=loginShell  by self write  by * read"
            ''
              {2}to dn.subtree="ou=system,ou=users,${cfg.ldapBaseDN}"
                               by dn.base="cn=dovecot,dc=mail,${cfg.ldapBaseDN}" read
                               by dn.subtree="ou=system,ou=users,${cfg.ldapBaseDN}" read
                               by * none''
            ''
              {3}to dn.subtree="ou=jabber,ou=users,${cfg.ldapBaseDN}"  by dn.base="cn=prosody,ou=system,ou=users,${cfg.ldapBaseDN}" write  by * read''
            "{4}to * by * read"
          ];
        };
        "olcOverlay=syncprov,olcDatabase={1}mdb".attrs = {
          objectClass = ["olcOverlayConfig" "olcSyncProvConfig"];
          olcOverlay = "syncprov";
          olcSpSessionLog = "100";
        };
        "olcDatabase={2}monitor".attrs = {
          olcDatabase = "{2}monitor";
          objectClass = ["olcDatabaseConfig" "olcMonitorConfig"];
          olcAccess = [
            ''
              {0}to *
                             by dn.exact="cn=netdata,ou=system,ou=users,${cfg.ldapBaseDN}" read
                             by * none''
          ];
        };

        "cn={1}bitwarden,cn=schema" = {
          attrs = {
            cn = "{1}bitwarden";
            objectClass = "olcSchemaConfig";
            olcObjectClasses = ''
              (1.3.6.1.4.1.28298.1.2.4 NAME 'bitwarden'
                            SUP uidObject AUXILIARY
                            DESC 'Added to an account to allow bitwarden access'
                            MUST (mail $ userPassword))'';
          };
        };
        "cn=sudo,cn=schema".attrs = {
          cn = "sudo";
          objectClass = "olcSchemaConfig";
          olcAttributeTypes = [
            "( 1.3.6.1.4.1.15953.9.1.1 NAME 'sudoUser' DESC 'User(s) who may  run sudo' EQUALITY caseExactIA5Match SUBSTR caseExactIA5SubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )"
            "( 1.3.6.1.4.1.15953.9.1.2 NAME 'sudoHost' DESC 'Host(s) who may run sudo' EQUALITY caseExactIA5Match SUBSTR caseExactIA5SubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )"
            "( 1.3.6.1.4.1.15953.9.1.3 NAME 'sudoCommand' DESC 'Command(s) to be executed by sudo' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )"
            "( 1.3.6.1.4.1.15953.9.1.4 NAME 'sudoRunAs' DESC 'User(s) impersonated by sudo (deprecated)' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )"
            "( 1.3.6.1.4.1.15953.9.1.5 NAME 'sudoOption' DESC 'Options(s) followed by sudo' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )"
            "( 1.3.6.1.4.1.15953.9.1.6 NAME 'sudoRunAsUser' DESC 'User(s) impersonated by sudo' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )"
            "( 1.3.6.1.4.1.15953.9.1.7 NAME 'sudoRunAsGroup' DESC 'Group(s) impersonated by sudo' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )"
            "( 1.3.6.1.4.1.15953.9.1.8 NAME 'sudoNotBefore' DESC 'Start of time interval for which the entry is valid' EQUALITY generalizedTimeMatch ORDERING generalizedTimeOrderingMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.24 )"
            "( 1.3.6.1.4.1.15953.9.1.9 NAME 'sudoNotAfter' DESC 'End of time interval for which the entry is valid' EQUALITY generalizedTimeMatch ORDERING generalizedTimeOrderingMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.24 )"
            "( 1.3.6.1.4.1.15953.9.1.10 NAME 'sudoOrder' DESC 'an integer to order the sudoRole entries' EQUALITY integerMatch ORDERING integerOrderingMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.27 )"
          ];
          olcObjectClasses = [
            "( 1.3.6.1.4.1.15953.9.2.1 NAME 'sudoRole' DESC 'Sudoer Entries' SUP top STRUCTURAL MUST cn MAY ( sudoUser $ sudoHost $ sudoCommand $ sudoRunAs $ sudoRunAsUser $ sudoRunAsGroup $ sudoOption $ sudoOrder $ sudoNotBefore $ sudoNotAfter $ description ) )"
          ];
        };
        "cn={1}squid,cn=schema".attrs = {
          cn = "{1}squid";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              (1.3.6.1.4.1.16548.1.2.4 NAME 'proxyUser'
                            SUP top AUXILIARY
                            DESC 'Account to allow a user to use the Squid proxy'
                            MUST ( mail $ userPassword ))
            ''
          ];
        };
        "cn={1}grafana,cn=schema".attrs = {
          cn = "{1}grafana";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              (1.3.6.1.4.1.28293.1.2.5 NAME 'grafana'
                             SUP uidObject AUXILIARY
                             DESC 'Added to an account to allow grafana access'
                             MUST (mail))
            ''
          ];
        };
        "cn={2}postfix,cn=schema".attrs = {
          cn = "{2}postfix";
          objectClass = "olcSchemaConfig";
          olcAttributeTypes = [
            ''
              (1.3.6.1.4.1.12461.1.1.1 NAME 'postfixTransport'
                             DESC 'A string directing postfix which transport to use'
                             EQUALITY caseExactIA5Match
                             SYNTAX 1.3.6.1.4.1.1466.115.121.1.26{20} SINGLE-VALUE)''
            ''
              (1.3.6.1.4.1.12461.1.1.5 NAME 'mailbox'
                             DESC 'The absolute path to the mailbox for a mail account in a non-default location'
                             EQUALITY caseExactIA5Match
                             SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 SINGLE-VALUE)''
            ''
              (1.3.6.1.4.1.12461.1.1.6 NAME 'quota'
                             DESC 'A string that represents the quota on a mailbox'
                             EQUALITY caseExactIA5Match
                             SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 SINGLE-VALUE)''
            ''
              (1.3.6.1.4.1.12461.1.1.8 NAME 'maildrop'
                             DESC 'RFC822 Mailbox - mail alias'
                             EQUALITY caseIgnoreIA5Match
                             SUBSTR caseIgnoreIA5SubstringsMatch
                             SYNTAX 1.3.6.1.4.1.1466.115.121.1.26{256})''
          ];
          olcObjectClasses = [
            ''
              (1.3.6.1.4.1.12461.1.2.1 NAME 'mailAccount'
                             SUP top AUXILIARY
                             DESC 'Mail account objects'
                             MUST ( mail $ userPassword )
                             MAY (  cn $ description $ quota))''
            ''
              (1.3.6.1.4.1.12461.1.2.2 NAME 'mailAlias'
                             SUP top STRUCTURAL
                             DESC 'Mail aliasing/forwarding entry'
                             MUST ( mail $ maildrop )
                             MAY ( cn $ description ))''
            ''
              (1.3.6.1.4.1.12461.1.2.3 NAME 'mailDomain'
                             SUP domain STRUCTURAL
                             DESC 'Virtual Domain entry to be used with postfix transport maps'
                             MUST ( dc )
                             MAY ( postfixTransport $ description  ))''
            ''
              (1.3.6.1.4.1.12461.1.2.4 NAME 'mailPostmaster'
                             SUP top AUXILIARY
                             DESC 'Added to a mailAlias to create a postmaster entry'
                             MUST roleOccupant)''
          ];
        };
        "cn={1}openssh,cn=schema".attrs = {
          cn = "{1}openssh";
          objectClass = "olcSchemaConfig";
          olcAttributeTypes = [
            ''
              (1.3.6.1.4.1.24552.500.1.1.1.13
                          NAME 'sshPublicKey'
                          DESC 'MANDATORY: OpenSSH Public key'
                          EQUALITY octetStringMatch
                          SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )''
          ];
          olcObjectClasses = [
            ''
              (1.3.6.1.4.1.24552.500.1.1.2.0
                          NAME 'ldapPublicKey'
                          SUP top AUXILIARY
                          DESC 'MANDATORY: OpenSSH LPK objectclass'
                          MUST ( sshPublicKey $ uid ))
            ''
          ];
        };
        "cn={1}nginx,cn=schema".attrs = {
          cn = "{1}nginx";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              (1.3.6.1.4.1.28295.1.2.4 NAME 'nginx'
                             SUP top AUXILIARY
                             DESC 'Added to an account to allow nginx access'
                             MUST ( mail $ userPassword ))
            ''
          ];
        };

        "cn={1}nextcloud,cn=schema".attrs = {
          cn = "{1}nextcloud";
          objectClass = "olcSchemaConfig";
          olcAttributeTypes = [
            ''
              (1.3.6.1.4.1.39430.1.1.1
                           NAME 'ownCloudQuota'
                           DESC 'User Quota (e.g. 15 GB)'
                           SYNTAX '1.3.6.1.4.1.1466.115.121.1.15')''
          ];
          olcObjectClasses = [
            ''
              (1.3.6.1.4.1.39430.1.2.1
                           NAME 'ownCloud'
                           DESC 'ownCloud LDAP Schema'
                           AUXILIARY
                           MUST ( mail $ userPassword )
                           MAY ( ownCloudQuota ))''
          ];
        };
        "cn={1}gitlab,cn=schema".attrs = {
          cn = "{1}gitlab";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              ( 1.3.6.1.4.1.28293.1.2.4 NAME 'gitlab'
                          SUP uidObject AUXILIARY
                          DESC 'Added to an account to allow gitlab access'
                          MUST (mail))
            ''
          ];
        };
        "cn={1}ejabberd,cn=schema".attrs = {
          cn = "{1}ejabberd";
          objectClass = "olcSchemaConfig";
          olcAttributeTypes = [
            ''
              (1.2.752.43.9.1.1
                          NAME 'jabberID'
                          DESC 'The Jabber ID(s) associated with this object. Used to map a JID to an LDAP account.'
                          EQUALITY caseIgnoreMatch
                          SYNTAX 1.3.6.1.4.1.1466.115.121.1.15)
            ''
          ];
        };
        "cn={2}ejabberd,cn=schema".attrs = {
          cn = "{2}ejabberd";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              (1.2.752.43.9.2.1
                          NAME 'jabberUser'
                          DESC 'A jabber user'
                          AUXILIARY
                          MUST ( jabberID ))
            ''
          ];
        };
        "cn={1}homeAssistant,cn=schema".attrs = {
          cn = "{1}homeAssistant";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              (1.3.6.1.4.1.28297.1.2.4 NAME 'homeAssistant'
                           SUP uidObject AUXILIARY
                           DESC 'Added to an account to allow home-assistant access'
                           MUST (mail) )
            ''
          ];
        };
        "cn={1}ttrss,cn=schema".attrs = {
          cn = "{1}ttrss";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = ''
            ( 1.3.6.1.4.1.28294.1.2.4 NAME 'ttrss'
                        SUP top AUXILIARY
                        DESC 'Added to an account to allow tinytinyrss access'
                        MUST ( mail $ userPassword ))'';
        };
        "cn={1}prometheus,cn=schema".attrs = {
          cn = "{1}prometheus";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              ( 1.3.6.1.4.1.28296.1.2.4
                          NAME 'prometheus'
                          SUP uidObject AUXILIARY
                          DESC 'Added to an account to allow prometheus access'
                          MUST (mail))
            ''
          ];
        };
        "cn={1}loki,cn=schema".attrs = {
          cn = "{1}loki";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              ( 1.3.6.1.4.1.28299.1.2.4
                          NAME 'loki'
                          SUP uidObject AUXILIARY
                          DESC 'Added to an account to allow loki access'
                          MUST (mail))
            ''
          ];
        };

        "cn={1}flood,cn=schema".attrs = {
          cn = "{1}flood";
          objectClass = "olcSchemaConfig";
          olcObjectClasses = [
            ''
              (1.3.6.1.4.1.28300.1.2.4 NAME 'flood'
                             SUP uidObject AUXILIARY
                             DESC 'Added to an account to allow flood access'
                             MUST (mail))
            ''
          ];
        };
      };
      # declarativeContents = {
      #   "${cfg.ldapBaseDN}" = ''
      #   # base.ldif
      #   # Base DN
      #   dn: ${cfg.ldapBaseDN}
      #   objectClass: top
      #   objectClass: dcObject
      #   objectClass: organization
      #   o: ${cfg.domain-name}
      #   dc: ${cfg.domain-name}
      #
      #   # Manager, aicampground.com
      #   dn: cn=Manager,${cfg.ldapBaseDN}
      #   cn: Manager
      #   description: LDAP administrator
      #   objectClass: organizationalRole
      #   objectClass: top
      #   roleOccupant: ${cfg.ldapBaseDN}
      #
      #   # People, ${cfg.ldapBaseDN}
      #   dn: ou=People,${cfg.ldapBaseDN}
      #   ou: People
      #   objectClass: top
      #   objectClass: organizationalUnit
      #
      #   # Groups, ${cfg.ldapBaseDN}
      #   dn: ou=Group,${cfg.ldapBaseDN}
      #   ou: Group
      #   objectClass: top
      #   objectClass: organizationalUnit
      #
      #   # groups.ldif
      #   # Begin Templated Group: ldap_user
      #   dn: cn=ldap_user,ou=Group,${cfg.ldapBaseDN}
      #   objectClass: top
      #   objectClass: posixGroup
      #   cn:ldap_user
      #   gidNumber: 10000
      #
      #   # End Templated Group
      #
      #   # Begin Templated Group: docker
      #   dn: cn=docker,ou=Group,${cfg.ldapBaseDN}
      #   objectClass: top
      #   objectClass: posixGroup
      #   cn:docker
      #   gidNumber: 10001
      #
      #   # End Templated Group
      #
      #   # Begin Templated Group: wheel
      #   dn: cn=wheel,ou=Group,${cfg.ldapBaseDN}
      #   objectClass: top
      #   objectClass: posixGroup
      #   cn:wheel
      #   gidNumber: 10002
      #
      #   # End Templated Group
      #
      #   # passwords.ldif
      #   #load password policy module
      #   dn: ou=pwpolicies,${cfg.ldapBaseDN}
      #   objectClass: organizationalUnit
      #   objectClass: top
      #   ou: pwpolicies
      #
      #   dn: cn=default,ou=pwpolicies,${cfg.ldapBaseDN}
      #   objectClass: top
      #   objectClass: device
      #   objectClass: pwdPolicy
      #   cn: default
      #   pwdAttribute: userPassword
      #   pwdAllowUserChange: TRUE
      #   pwdCheckQuality: 1
      #   pwdExpireWarning: 3600
      #   pwdFailureCountInterval: 3600
      #   pwdInHistory: 3
      #   pwdLockout: TRUE
      #   pwdLockoutDuration: 300
      #   pwdMaxAge: 0
      #   pwdMaxFailure: 5
      #   pwdMinLength: 6
      #   pwdMustChange: FALSE
      #   pwdSafeModify: FALSE
      #
      #   dn: ou=sudoers,${cfg.ldapBaseDN}
      #   objectClass: organizationalUnit
      #   objectClass: top
      #   ou: sudoers
      #
      #   dn: cn=defaults,ou=sudoers,${cfg.ldapBaseDN}
      #   objectClass: sudoRole
      #   objectClass: top
      #   cn: defaults
      #   sudoOption: env_reset
      #   sudoOption: mail_badpass
      #   sudoOption: secure_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
      #   sudoOrder: 1
      #
      #   # Entry: cn=docker,ou=sudoers,${cfg.ldapBaseDN}
      #   dn: cn=docker,ou=sudoers,${cfg.ldapBaseDN}
      #   cn: docker
      #   objectclass: sudoRole
      #   objectclass: top
      #   sudocommand: /usr/sbin/docker
      #   sudohost: ALL
      #   sudooption: !authenticate
      #   sudoorder: 2
      #   sudorunasuser: root
      #   sudouser: %docker
      #
      #   # Entry: cn=wheel,ou=sudoers,${cfg.ldapBaseDN}
      #   dn: cn=wheel,ou=sudoers,${cfg.ldapBaseDN}
      #   cn: wheel
      #   objectclass: sudoRole
      #   objectclass: top
      #   sudocommand: ALL
      #   sudohost: ALL
      #   sudoorder: 2
      #   sudorunasuser: ALL
      #   sudouser: %wheel
      #
      #   dn: cn=k8s,ou=Group,${cfg.ldapBaseDN}
      #   cn: k8s
      #   gidnumber: 999
      #   objectclass: posixGroup
      #   objectclass: top
      #
      #   dn: cn=libvirtd,ou=Group,${cfg.ldapBaseDN}
      #   cn: libvirtd
      #   gidnumber: 5001
      #   objectclass: posixGroup
      #   objectclass: top
      #   '';
      # # "cn=config" = ''
      # #
      # #   '';
      # };
    };

    fmf.services.vault-agent.services.openldap = {
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
            "ldap.crt" = {
              text = ''
                {{ with secret "${cfg.vault-pki-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.certificate }}
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
            "ldap.key" = {
              text = ''
                {{ with secret "${cfg.vault-pki-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.private_key }}
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
            "ca.crt" = {
              text = ''
                {{ with secret "${cfg.vault-pki-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.issuing_ca }}
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
            "olcRootPW.secret" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.olcRootPW }}{{ else }}{{ .Data.data.olcRootPW }}{{ end }}{{ end }}'';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
