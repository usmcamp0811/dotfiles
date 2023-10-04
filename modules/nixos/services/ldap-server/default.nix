{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.ldap-server;

  sudoSchemaPath = ./openldap/sudo-config.ldif;
in
{
  options.campground.services.ldap-server = with types; {
    enable = mkBoolOpt false "Enable Docker;";
    ldapBackend = mkOpt str "mdb" "the Ldap Backend";
    ldapBaseDN = mkOpt str "dc=aicampground,dc=com" "The BaseDN"; domain-name = mkOpt str "aicampground" "The domain name to use";
    rootdn = mkOpt str "cn=admin,dc=${cfg.domain-name},dc=com" "The Root DN to use";
    suffix = mkOpt str "dc=${cfg.domain-name},dc=com" "The suffix";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "campground-pki/issue/ldap-server-role" "The Vault path to the Server Cert in Vault";
    common-name = mkOpt str "ldap.server.aicampground.com" "Common Name for Server Certs";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 389 8080 ]; # OpenLDAP and phpLDAPadmin ports

    virtualisation.oci-containers.containers = {
      phpldapadmin = {
        image = "osixia/phpldapadmin:latest";
        ports = ["8080:80"];
        environment = {
          PHPLDAPADMIN_LDAP_HOSTS = "10.8.0.135"; # Replace with your LDAP server address
          PHPLDAPADMIN_HTTPS = "false";
        };
      };
    };


    services.openldap = {
      enable = true;
      # rootdn = "cn=admin,${cfg.ldapBaseDN}";
      # rootpw = "{CLEARTEXT}admin"; # Use a more secure method in production

      /* enable plain connections only */
      urlList = [ "ldap:///" ];

      settings = {
        attrs = {
          olcLogLevel = "conns config";
          /* settings for acme ssl */
          olcTLSCACertificateFile = "/tmp/detsys-vault/ca.crt";
          olcTLSCertificateFile = "/tmp/detsys-vault/ldap.crt";
          olcTLSCertificateKeyFile = "/tmp/detsys-vault/ldap.key";
          olcTLSCipherSuite = "HIGH:MEDIUM:+3DES:+RC4:+aNULL";
          olcTLSCRLCheck = "none";
          olcTLSVerifyClient = "never";
          olcTLSProtocolMin = "3.1";
        };

        children = {
          "cn=schema".includes = [
            "${pkgs.openldap}/etc/schema/core.ldif"
            "${pkgs.openldap}/etc/schema/cosine.ldif"
            "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
            "${pkgs.openldap}/etc/schema/nis.ldif"
          ];
          "olcDatabase={1}mdb".attrs = {

            objectClass = [ "olcDatabaseConfig" "olcMdbConfig" ];

            olcDatabase = "{1}mdb";
            olcDbDirectory = "/var/lib/openldap/data";

            olcSuffix = cfg.ldapBaseDN;

            /* your admin account, do not use writeText on a production system */
            olcRootDN = "cn=admin,${cfg.ldapBaseDN}";
            olcRootPW.path = pkgs.writeText "olcRootPW" "pass";

            olcAccess = [
              # /* custom access rules for userPassword attributes */
              # ''{0}to attrs=userPassword
              #     by self write
              #     by anonymous auth
              #     by * none''
              #
              # /* allow read on anything else */
              # ''{1}to *
              #     by * read''

              "to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break"
              "to attrs=userPassword,shadowLastChange by self write by dn=\"cn=admin,dc=aicampground,dc=com\" write by anonymous auth by * none"
              "to * by anonymous read by dn=\"cn=admin,dc=aicampground,dc=com\" write by * none"
            ];
          };
        };
      };
    declarativeContents = ''
      dn: ou=Group,dc=aicampground,dc=com
      objectClass: top
      objectClass: organizationalUnit
      ou: Group

      dn: cn=ldap_user,ou=Group,dc=aicampground,dc=com
      objectClass: top
      objectClass: posixGroup
      cn: ldap_user
      gidNumber: 10000

      dn: cn=docker,ou=Group,dc=aicampground,dc=com
      objectClass: top
      objectClass: posixGroup
      cn: docker
      gidNumber: 10001

      dn: cn=wheel,ou=Group,dc=aicampground,dc=com
      objectClass: top
      objectClass: posixGroup
      cn: wheel
      gidNumber: 10002
    '';
    };

    campground.services.vault-agent.services.openldap = {
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
            "ldap.crt" = {
              text = ''
                {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.certificate }}
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
            "ldap.key" = {
              text = ''
                {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
                {{ .Data.private_key }}
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
            "ca.crt" = {
              text = ''
                {{ with secret "${cfg.vault-path}" "common_name=${cfg.common-name}" }}
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
