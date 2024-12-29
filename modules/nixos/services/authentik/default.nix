{ host ? "", options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.services.authentik;
  authentikDir = "/var/lib/authentik";
in
{
  options.campground.services.authentik = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable Authentik configuration.";
    port = mkOpt int 8435 "Port to Host the Authentik server.";
    avatars = mkOpt str "initials" "Avatars to use?";
  };

  config = mkIf cfg.enable {
    services.authentik = {
      enable = true;
      # The environmentFile needs to be on the target host!
      # Best use something like sops-nix or agenix to manage it
      environmentFile = "${authentikDir}/environmentFile";
      settings = {
        disable_startup_analytics = true;
        avatars = cfg.avatars;
      };
    };
    systemd.services.authentikSecrets = {
      description = "Get Authentik Secrets";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p ${authentikDir}
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/environmentFile ${authentikDir}/environmentFile
        chown -R authentik:authentik ${authentikDir}
      '';
      wantedBy = [ "multi-user.target" ];
      before = [
        "authentik-migrate.service"
        "authentik-worker.service"
        "authentik.service"
        "authentik-ldap.service"
        "authentik-radius.service"
      ];

    };
    campground.services.vault-agent.services = {
      authentikSecrets = {
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
              "environmentFile" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.dbpass }}{{ else }}{{ .Data.data.dbpass }}{{ end }}{{ end }}'';
                permissions = "0600";
                change-action = "restart";
              };
            };
          };
        };
      };
    };
  };
}
