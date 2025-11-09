{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.campground.services.crystal-forge;

  host = config.networking.hostName;

  # local-only keys; everything else is forwarded to services.crystal-forge
  reserved = [
    "enable"
    "role-id"
    "secret-id"
    "vault-path"
    "kvVersion"
    "vault-address"
  ];

  passthrough = builtins.removeAttrs cfg reserved;
in {
  options.campground.services.crystal-forge = mkOption {
    type = types.submodule {
      # allow all upstream CF trees (server.*, builder.*, cache.*, build.*, …)
      freeformType = with types; attrsOf anything;

      options = {
        enable = mkEnableOption "Crystal Forge via campground downstream shim";

        # --- Vault Agent knobs (exactly as requested) ---
        role-id = mkOption {
          type = types.str;
          default = config.campground.services.vault-agent.settings.vault.role-id;
          description = "Absolute path to the Vault role-id";
        };

        secret-id = mkOption {
          type = types.str;
          default = config.campground.services.vault-agent.settings.vault.secret-id;
          description = "Absolute path to the Vault secret-id";
        };

        vault-path = mkOption {
          type = types.str;
          default = "secret/campground/crystal-forge";
          description = "The Vault path to the KV containing the KVs that are for each database";
        };

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
    };
    default = {};
    description = "Downstream CF namespace; forwards all non-Vault keys to services.crystal-forge.";
  };

  config = mkIf cfg.enable {
    # 1) Forward everything except our Vault knobs to upstream CF module.
    services.crystal-forge = passthrough;

    # 2) Your Vault-Agent service shim (verbatim; uses cfg.*, host)
    campground.services = {
      vault-agent = {
        services = {
          "crystal-forge-setup" = {
            settings = {
              vault.address = cfg.vault-address;
              auto_auth = {
                method = [
                  {
                    type = "approle";
                    config = {
                      role_id_file_path = cfg."role-id";
                      secret_id_file_path = cfg."secret-id";
                      remove_secret_id_file_after_reading = false;
                    };
                  }
                ];
              };
            };
            secrets = {
              file = {
                files = {
                  "attic-env" = lib.mkIf (cfg.cache.cache_type == "Attic" && cfg.cache.push_to != null) {
                    text = ''
                      ATTIC_SERVER_URL=${cfg.cache.push_to}
                      ATTIC_TOKEN={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.attic_token }}{{ else }}{{ .Data.data.attic_token }}{{ end }}{{ end }}
                      ATTIC_REMOTE_NAME=${cfg.cache.attic_cache_name}
                      HOME=/var/lib/crystal-forge
                      XDG_CONFIG_HOME=/var/lib/crystal-forge/.config
                    '';
                    permissions = "0644";
                    change-action = "restart";
                  };

                  "s3-env" = lib.mkIf (cfg.cache.cache_type == "S3" && cfg.cache.push_to != null) {
                    text = ''
                      AWS_ACCESS_KEY_ID={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.minio_access_key }}{{ else }}{{ .Data.data.minio_access_key }}{{ end }}{{ end }}
                      AWS_SECRET_ACCESS_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.minio_secret_key }}{{ else }}{{ .Data.data.minio_secret_key }}{{ end }}{{ end }}
                      ${lib.optionalString (cfg.cache.s3_region != null) "AWS_REGION=${cfg.cache.s3_region}"}
                      AWS_EC2_METADATA_DISABLED=true
                      HOME=/var/lib/crystal-forge
                      XDG_CONFIG_HOME=/var/lib/crystal-forge/.config
                    '';
                    permissions = "0644";
                    change-action = "restart";
                  };

                  "signing-key" = lib.mkIf (cfg.cache.cache_type == "S3" && cfg.cache.push_to != null) {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}
                      {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.signing_key }}{{ else }}{{ .Data.data.signing_key }}{{ end }}
                      {{ end }}
                    '';
                    permissions = "0600";
                    change-action = "restart";
                  };

                  "agent.key" = {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}
                      {{ if eq "${cfg.kvVersion}" "v1" }}
                        {{ index .Data "${host}" }}
                      {{ else }}
                        {{ index .Data.data "${host}" }}
                      {{ end }}
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

    # 3) A systemd oneshot shim that runs after Vault Agent and before CF
    systemd.services."crystal-forge-setup" = {
      description = "Crystal Forge setup shim (between Vault Agent and CF)";
      wantedBy = ["multi-user.target"];
      after = ["vault-agent.service"];
      wants = ["vault-agent.service"];
      before = [
        "crystal-forge-server.service"
        "crystal-forge-builder.service"
        "crystal-forge-postgres-jobs.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "crystal-forge-setup.sh" ''
          set -euo pipefail
          # Minimal shim to enforce ordering; extend with checks if/when needed.
          echo "crystal-forge-setup: Vault templates should be ready."
        '';
      };
    };

    # 4) Ensure CF units *want* and start *after* the setup shim
    #    Include a likely Vault-Agent unit name too; harmless if absent.
    systemd.services."crystal-forge-server".wants = ["crystal-forge-setup.service" "vault-agent-crystal-forge-setup.service"];
    systemd.services."crystal-forge-server".after = ["crystal-forge-setup.service" "vault-agent-crystal-forge-setup.service"];

    systemd.services."crystal-forge-builder".wants = ["crystal-forge-setup.service" "vault-agent-crystal-forge-setup.service"];
    systemd.services."crystal-forge-builder".after = ["crystal-forge-setup.service" "vault-agent-crystal-forge-setup.service"];

    systemd.services."crystal-forge-postgres-jobs".wants = ["crystal-forge-setup.service" "vault-agent-crystal-forge-setup.service"];
    systemd.services."crystal-forge-postgres-jobs".after = ["crystal-forge-setup.service" "vault-agent-crystal-forge-setup.service"];
  };
}
