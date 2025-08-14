{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.github-runner;
in {
  options.campground.services.github-runner = {
    enable = mkEnableOption "GitHub Actions Runner";

    runners = mkOption {
      description = "Multiple GitHub Runners configuration";
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "this GitHub runner";

          url = mkOption {
            type = types.str;
            description = ''
              Repository or organization to add the runner to.
              For org-wide runners: https://github.com/orgname
              For repo-specific: https://github.com/owner/repo
            '';
            example = "https://github.com/nixos/nixpkgs";
          };

          runner-name = mkOpt types.str name "Name of the runner";

          runnerGroup = mkOption {
            type = types.nullOr types.str;
            description = "Name of the runner group to add this runner to";
            default = null;
          };

          extraLabels = mkOption {
            type = types.listOf types.str;
            description = "Extra labels in addition to the default ones";
            example = ["nix" "docker"];
            default = [];
          };

          noDefaultLabels = mkOption {
            type = types.bool;
            description = "Disable adding the default labels";
            default = false;
          };

          replace = mkOption {
            type = types.bool;
            description = "Replace any existing runner with the same name";
            default = false;
          };

          ephemeral = mkOption {
            type = types.bool;
            description = ''
              Enable ephemeral runner mode.
              Runner will de-register after processing one job and restart.
              Requires a PAT token, not a registration token.
            '';
            default = false;
          };

          extraPackages = mkOption {
            type = types.listOf types.package;
            description = "Extra packages to add to PATH";
            default = with pkgs; [
              git
              nix
              cacert
              openssh
              deploy-rs
              campground.get-lan-pub-systems
              vault
              ssh-agents
              attic-client
            ];
          };

          extraEnvironment = mkOption {
            type = types.attrs;
            description = "Extra environment variables for the runner";
            default = {
              NIX_REMOTE = "daemon";
              NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
            };
          };

          serviceOverrides = mkOption {
            type = types.attrs;
            description = "Systemd service overrides";
            default = {};
          };

          workDir = mkOption {
            type = types.nullOr types.str;
            description = "Working directory for the runner";
            default = null;
          };

          user = mkOption {
            type = types.nullOr types.str;
            description = "User to run the service as";
            default = null;
          };

          group = mkOption {
            type = types.nullOr types.str;
            description = "Group to run the service as";
            default = null;
          };
        };
      }));
    };

    # Vault configuration
    role-id =
      mkOpt types.str
      config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";

    secret-id =
      mkOpt types.str
      config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";

    vault-path =
      mkOpt types.str "secret/campground/github-runner"
      "The Vault path to the KV containing the runner tokens";

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
    # Enable Docker for containerized actions
    virtualisation.docker.enable = true;

    # Configure the upstream GitHub runners
    services.github-runners =
      mapAttrs (runnerName: runnerCfg: {
        inherit (runnerCfg) enable url runnerGroup extraLabels noDefaultLabels replace ephemeral extraPackages serviceOverrides workDir user group;

        name = runnerCfg.runner-name;
        tokenFile = "/tmp/detsys-vault/github-runner-${runnerName}-token";

        # Add nix-specific packages and environment
        extraEnvironment = runnerCfg.extraEnvironment;
      })
      cfg.runners;

    # Configure Vault agent for each runner
    campground = {
      services = {
        vault-agent = {
          services = {
            "github-runner" = {
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
                  files = mkMerge (
                    mapAttrsToList (
                      runnerName: runnerCfg:
                        mkIf runnerCfg.enable {
                          "github-runner-${runnerName}-token" = {
                            text = ''
                              {{ with secret "${cfg.vault-path}" }}
                              {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${runnerCfg.runner-name}_TOKEN }}{{ else }}{{ .Data.data.${runnerCfg.runner-name}_TOKEN }}{{ end }}
                              {{ end }}
                            '';
                            permissions = "0600";
                            change-action = "restart";
                          };
                        }
                    )
                    cfg.runners
                  );
                };
              };
            };
          };
        };
      };
    };
    # Ensure nix daemon is available for runners
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users =
        ["root"]
        ++ (map (runnerCfg: runnerCfg.user)
          (filter (runnerCfg: runnerCfg.user != null)
            (attrValues cfg.runners)));
    };

    # Create necessary nix directories and permissions
    system.activationScripts.github-runners-nix-setup = ''
      mkdir -p -m 0755 /nix/var/log/nix/drvs
      mkdir -p -m 0755 /nix/var/nix/gcroots
      mkdir -p -m 0755 /nix/var/nix/profiles
      mkdir -p -m 0755 /nix/var/nix/temproots
      mkdir -p -m 0755 /nix/var/nix/userpool
      mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
      mkdir -p -m 1777 /nix/var/nix/profiles/per-user
    '';
  };
}
