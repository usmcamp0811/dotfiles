{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.vaultwarden;
  ldapConfig = {
    vaultwarden_url = "https://bitwarden.thalheim.io";
    vaultwarden_admin_token = "@ADMIN_TOKEN@";
    ldap_host = "ldap.campground.lan";
    ldap_bind_dn = "cn=bitwarden,ou=system,ou=users,dc=campground,dc=com";
    ldap_bind_password = "@LDAP_PASSWORD@";
    ldap_search_base_dn = "ou=users,dc=campground,dc=com";
    ldap_search_filter = "(&(objectClass=bitwarden))";
    ldap_sync_interval_seconds = 3600;
  };

  ldapConfigFile =
    pkgs.runCommand "config.toml"
      {
        buildInputs = [ pkgs.remarshal ];
        preferLocalBuild = true;
      } ''
      remarshal -if json -of toml \
      < ${pkgs.writeText "config.json" (builtins.toJSON ldapConfig)} \
      > $out
    '';
in
{
  options.campground.services.vaultwarden = with types; {
    enable = mkBoolOpt false "Enable Vaultwarden;";
  };

  config = mkIf cfg.enable {

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    config = {
      domain = "todo";
      signupsAllowed = false;
      rocketPort = 3011;
      databaseUrl = "postgresql://vaultwarden@%2Frun%2Fpostgresql/bitwarden_rs";
      enableDbWal = "false";
      websocketEnabled = true;
      smtpHost = "todo";
      smtpFrom = "todo";
      smtpUsername = "todo";
    };
  };

  # systemd.services.vaultwarden.serviceConfig = {
  #   EnvironmentFile = [ config.sops.secrets.bitwarden-smtp-password.path ];
  # };

  # systemd.services.vaultwarden_ldap = {
  #   wantedBy = [ "multi-user.target" ];
  #
  #   preStart = ''
  #     sed \
  #       -e "s=@LDAP_PASSWORD@=$(<${config.sops.secrets.bitwarden-ldap-password.path})=" \
  #       -e "s=@ADMIN_TOKEN@=$(<${config.sops.secrets.bitwarden-admin-token.path})=" \
  #       ${ldapConfigFile} \
  #       > /run/vaultwarden_ldap/config.toml
  #   '';
  #
  #   serviceConfig = {
  #     Restart = "on-failure";
  #     RestartSec = "2s";
  #     ExecStart = "${inputs.nur-packages.packages.${pkgs.hostPlatform.system}.vaultwarden_ldap}/bin/vaultwarden_ldap";
  #     Environment = "CONFIG_PATH=/run/vaultwarden_ldap/config.toml";
  #
  #     RuntimeDirectory = [ "vaultwarden_ldap" ];
  #     User = "vaultwarden_ldap";
  #   };
  # };

  services.nginx = {
    virtualHosts."bitwarden.lan" = {
      # useACMEHost = "thalheim.io";
      # forceSSL = true;
      extraConfig = ''
        client_max_body_size 128M;
      '';
      locations."/" = {
        proxyPass = "http://localhost:3011";
        proxyWebsockets = true;
      };
      locations."/notifications/hub" = {
        proxyPass = "http://localhost:3012";
        proxyWebsockets = true;
      };
      locations."/notifications/hub/negotiate" = {
        proxyPass = "http://localhost:3011";
        proxyWebsockets = true;
      };
    };
  };

  users.users.vaultwarden_ldap = {
    isSystemUser = true;
    group = "vaultwarden_ldap";
  };

  users.groups.vaultwarden_ldap = { };
  };
}
