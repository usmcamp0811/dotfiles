{ lib
, config
, pkgs
, inputs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.gitlab-runner;

  CI_SERVER_URL = "${cfg.runner-name}_CI_SERVER_URL";
  REGISTRATION_TOKEN = "${cfg.runner-name}_REGISTRATION_TOKEN";
in
{
  options.campground.services.gitlab-runner = {
    enable = mkEnableOption "GitLab Runner";
    runner-name =
      mkOpt types.str config.networking.hostName
        "Name used in Vault to deleniate runners";

    role-id =
      mkOpt types.str
        config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
        config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/gitlab-runner"
        "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = types.enum [ "v1" "v2" ];
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
    boot.kernel.sysctl."net.ipv4.ip_forward" = true; # 1
    virtualisation.docker.enable = true;
    services.gitlab-runner = {
      enable = true;
      services = {
        # runner for building in docker via host's nix-daemon
        # nix store will be readable in runner, might be insecure

        nix = with lib; {
          authenticationTokenConfigFile =
            toString /tmp/detsys-vault/config.toml; # 2
          # File should contain at least these two variables:
          # `CI_SERVER_URL`
          # `REGISTRATION_TOKEN`
          # registrationConfigFile =
          dockerImage = "alpine";
          dockerVolumes = [
            "/nix/store:/nix/store:ro"
            "/nix/var/nix/db:/nix/var/nix/db:ro"
            "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
            "/root/.config/attic:/root/.config/attic:ro"
          ];
          dockerDisableCache = true;
          preBuildScript = pkgs.writeScript "setup-container" ''
            set -e

            mkdir -p -m 0755 /nix/var/log/nix/drvs
            mkdir -p -m 0755 /nix/var/nix/gcroots
            mkdir -p -m 0755 /nix/var/nix/profiles
            mkdir -p -m 0755 /nix/var/nix/temproots
            mkdir -p -m 0755 /nix/var/nix/userpool
            mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
            mkdir -p -m 1777 /nix/var/nix/profiles/per-user
            mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
            mkdir -p -m 0700 "$HOME/.nix-defexpr"
            mkdir -p -m 0755 /etc/nix

            . ${pkgs.nix}/etc/profile.d/nix-daemon.sh

            ${pkgs.nix}/bin/nix-env -i ${
              concatStringsSep " " (with pkgs; [
                nix
                cacert
                git
                openssh
                deploy-rs
                campground.get-lan-pub-systems
                vault
                ssh-agents
                attic-client
              ])
            }

            echo "extra-experimental-features = nix-command flakes" >> /etc/nix/nix.conf
            echo "allowed-unfree = true" >> /etc/nix/nix.conf
            chmod 644 /etc/nix/nix.conf

            # Removed channel commands - not needed with flakes
          '';
          environmentVariables = {
            ENV = "/etc/profile";
            USER = "root";
            NIX_REMOTE = "daemon";
            PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
            NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
          };
          # tagList = [ "nix" ];
        };
      };
    };

    campground = {
      services = {
        vault-agent = {
          services = {
            "gitlab-runner" = {
              settings = {
                # replace with the address of your vault
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
                    "config.toml" = {
                      text = ''
                        {{ with secret "${cfg.vault-path}" }}
                        CI_SERVER_URL='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${CI_SERVER_URL} }}{{ else }}{{ .Data.data.${CI_SERVER_URL} }}{{ end }}'
                        CI_SERVER_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${REGISTRATION_TOKEN} }}{{ else }}{{ .Data.data.${REGISTRATION_TOKEN} }}{{ end }}'
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
        };
      };
    };
  };
}
