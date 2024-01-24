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

    boot.kernel.sysctl."net.ipv4.ip_forward" = true; # 1
    virtualisation.docker.enable = true;
    services.gitlab-runner = {
      enable = true;
      services= {
        # runner for building in docker via host's nix-daemon
        # nix store will be readable in runner, might be insecure
        nix = with lib;{
          # File should contain at least these two variables:
          # `CI_SERVER_URL`
          # `REGISTRATION_TOKEN`
          registrationConfigFile = toString ./path/to/ci-env; # 2
          dockerImage = "alpine";
          dockerVolumes = [
            "/nix/store:/nix/store:ro"
            "/nix/var/nix/db:/nix/var/nix/db:ro"
            "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
          ];
          dockerDisableCache = true;
          preBuildScript = pkgs.writeScript "setup-container" ''
            mkdir -p -m 0755 /nix/var/log/nix/drvs
            mkdir -p -m 0755 /nix/var/nix/gcroots
            mkdir -p -m 0755 /nix/var/nix/profiles
            mkdir -p -m 0755 /nix/var/nix/temproots
            mkdir -p -m 0755 /nix/var/nix/userpool
            mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
            mkdir -p -m 1777 /nix/var/nix/profiles/per-user
            mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
            mkdir -p -m 0700 "$HOME/.nix-defexpr"
            . ${pkgs.nix}/etc/profile.d/nix-daemon.sh
            ${pkgs.nix}/bin/nix-channel --add https://nixos.org/channels/nixos-20.09 nixpkgs # 3
            ${pkgs.nix}/bin/nix-channel --update nixpkgs
            ${pkgs.nix}/bin/nix-env -i ${concatStringsSep " " (with pkgs; [ nix cacert git openssh ])}
          '';
          environmentVariables = {
            ENV = "/etc/profile";
            USER = "root";
            NIX_REMOTE = "daemon";
            PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
            NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
          };
          tagList = [ "nix" ];
        };
      };
    };

    # users = {
    #   users = optionalAttrs (cfg.user == "gitlab-runner") {
    #     gitlab-runner = {
    #       group = cfg.group;
    #       isSystemUser = true;
    #     };
    #   };
    #   groups = optionalAttrs (cfg.group == "gitlab-runner") {
    #     gitlab-runner = { };
    #   };
    # };

    # systemd.services.gitlab-runner = {
    #   description = "GitLab Runner";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Restart = "always";
    #     User = "gitlab-runner";
    #     Group = "gitlab-runner";
    #   };
    #   script = ''
    #   ${pkgs.gitlab-runner}/bin/gitlab-runner run --config /tmp/detsys-vault/config.toml 
    #   '';
    # };

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
