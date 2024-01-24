{ lib, config, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.services.gitlab-runner;
in
{
  options.campground.services.gitlab-runner = {
    enable = mkEnableOption "GitLab Runner";
    user = mkOpt types.str "gitlab-runner" "The user under which gitlab-runner runs.";
    group = mkOpt types.str "gitlab-runner" "The group under which gitlab-runner runs.";

    role-id = mkOpt types.str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt types.str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt types.str "secret/campground/gitlab-runner" "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    users = {
      users = optionalAttrs (cfg.user == "gitlab-runner") {
        gitlab-runner = {
          group = cfg.group;
          isSystemUser = true;
        };
      };
      groups = optionalAttrs (cfg.group == "gitlab-runner") {
        gitlab-runner = { };
      };
    };

    systemd.services.gitlab-runner = {
      description = "GitLab Runner";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "always";
        User = "gitlab-runner";
        Group = "gitlab-runner";
      };
      script = ''
      ${pkgs.gitlab-runner}/bin/gitlab-runner run --config /tmp/detsys-vault/config.toml 
      '';
    };

    # systemd.services.copyConfig = {
    #   description = "Copy the gitlab runner config from Vault to /var/lib/vault/gitlab-runner.toml";
    #   serviceConfig = {
    #     Type = "oneshot";
    #     User = "root";
    #   };
    #   before = [ "gitlab-runner.service" ];
    # };
    #
    campground = {
      services = {
        vault-agent = {
          services = {
            "gitlab-runner" = {
              settings = {       # replace with the address of your vault
                vault.address = "https://vault.lan.aicampground.com";
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
                    "config.toml" = {
                      text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.config }}{{ else }}{{ .Data.data.config }}{{ end }}{{ end }}'';
                      permissions = "0600";
                      change-action = "restart";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
