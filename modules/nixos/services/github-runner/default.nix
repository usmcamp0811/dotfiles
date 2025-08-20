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
      mapAttrs
      (name: runnerCfg: {
        inherit
          (runnerCfg)
          enable
          url
          runnerGroup
          extraLabels
          noDefaultLabels
          replace
          ephemeral
          extraPackages
          serviceOverrides
          workDir
          user
          group
          ;

        name = runnerCfg.runner-name;

        tokenFile = "/var/lib/github-runner/${name}.token";

        extraEnvironment = runnerCfg.extraEnvironment;
      })
      cfg.runners;

    # Fix for the token copy oneshot service ordering issue
    systemd.services =
      # GitHub runner services that depend on token copy
      (builtins.listToAttrs (mapAttrsToList (name: runnerCfg: {
          name = "github-runner-${name}";
          value = mkIf runnerCfg.enable {
            requires = ["github-runner-token-copy-${name}.service"];
            after = ["github-runner-token-copy-${name}.service"];
          };
        })
        cfg.runners))
      //
      # Token copy oneshot services (one per runner)
      (builtins.listToAttrs (mapAttrsToList (name: runnerCfg: {
          name = "github-runner-token-copy-${name}";
          value = mkIf runnerCfg.enable {
            description = "Copy GitHub Runner token for ${name}";
            # Remove the before/wantedBy that might be causing circular deps
            # before = ["github-runner-${name}.service"];
            # wantedBy = ["github-runner-${name}.service"];

            # Instead, make it wanted by multi-user.target so it starts early
            wantedBy = ["multi-user.target"];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true; # Important for oneshot services that other services depend on
              ExecStart = pkgs.writeShellScript "copy-gh-runner-token-${name}" ''
                set -euo pipefail

                echo "=== GitHub Runner Token Copy Service for ${name} ==="
                echo "Starting at $(date)"

                src="/tmp/detsys-vault/github-runner-${name}-token"
                dst="/var/lib/github-runner/${name}.token"

                echo "Source file: $src"
                echo "Destination: $dst"

                # Debug: List vault temp directory
                echo "Contents of /tmp/detsys-vault/:"
                ls -la /tmp/detsys-vault/ || echo "Directory does not exist"

                # Wait for the vault token file to exist (with timeout)
                echo "Waiting for vault token file..."
                timeout=60  # Increased timeout
                while [ ! -f "$src" ] && [ $timeout -gt 0 ]; do
                  echo "Waiting for vault token file: $src (timeout: $timeout)"
                  sleep 2
                  timeout=$((timeout - 2))
                done

                if [ ! -f "$src" ]; then
                  echo "ERROR: Vault token file not found: $src"
                  echo "Available files in /tmp/detsys-vault/:"
                  ls -la /tmp/detsys-vault/ || echo "Directory does not exist"
                  echo "Vault-agent services status:"
                  systemctl list-units | grep vault-agent || echo "No vault-agent services found"
                  exit 1
                fi

                echo "Found vault token file: $src"
                echo "File size: $(wc -c < "$src") bytes"

                # Create destination directory
                install -d -m 0700 "/var/lib/github-runner/${name}"
                echo "Created directory: /var/lib/github-runner/${name}"

                # Copy the token file
                cat "$src" > "$dst"
                chmod 0600 "$dst"

                # Set correct ownership if service runs as specific user
                if getent passwd github-runner >/dev/null 2>&1; then
                  chown github-runner:github-runner "$dst"
                  echo "Set ownership to github-runner:github-runner"
                else
                  echo "Using root ownership (no github-runner user found)"
                fi

                echo "Successfully copied token to $dst"
                echo "Token file size: $(wc -c < "$dst") bytes"

                # Ensure the file is fully written and accessible
                sync
                sleep 1

                echo "Token file verified and accessible"
                echo "Completed at $(date)"
              '';
            };
          };
        })
        cfg.runners))
      //
      # Add restart trigger for nix-daemon
      {
        nix-daemon = {
          restartTriggers = [config.nix.settings.trusted-users];
        };
      };

    # Configure Vault agent for each runner
    campground.services.vault-agent.services = builtins.listToAttrs (
      mapAttrsToList (name: runnerCfg: {
        name = "github-runner-token-copy-${name}";
        value = mkIf runnerCfg.enable {
          settings = {
            vault.address = cfg.vault-address;
            auto_auth.method = [
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
          secrets.file.files."github-runner-${name}-token" = {
            text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ index .Data "${runnerCfg.runner-name}_TOKEN" }}{{ else }}{{ index .Data.data "${runnerCfg.runner-name}_TOKEN" }}{{ end }}{{ end }}'';
            permissions = "0600";
            change-action = "restart";
          };
        };
      })
      cfg.runners
    );

    # Ensure nix daemon is available for runners
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users =
        ["root" "github-runner"]
        ++ (lib.lists.unique (
          lib.lists.filter (user: user != null) (
            map (runnerCfg: runnerCfg.user) (attrValues cfg.runners)
          )
        ))
        # Add the actual runner service users that NixOS creates
        ++ (map (name: "github-runner-${name}")
          (attrNames (lib.attrsets.filterAttrs (n: v: v.enable) cfg.runners)));
    };

    # Add github-runner users to necessary groups
    users.users = builtins.listToAttrs (
      map (name: {
        name = "github-runner-${name}";
        value = {
          extraGroups = ["docker"];
        };
      }) (attrNames (lib.attrsets.filterAttrs (n: v: v.enable) cfg.runners))
    );

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
