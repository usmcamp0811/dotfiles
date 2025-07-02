{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.crystal-forge;

  host = config.networking.hostName;
in {
  options.campground.services.crystal-forge = {
    enable = mkEnableOption "Enable the Crystal Forge service(s)";
    log_level = lib.mkOption {
      type = lib.types.enum ["off" "error" "warn" "info" "debug" "trace"];
      default = "debug";
    };
    configPath = mkOption {
      type = types.path;
      default = generatedConfigPath;
      description = "Path to the final config.toml file.";
    };
    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
      };
      user = mkOption {
        type = types.str;
        default = "crystal_forge";
      };
      password = mkOption {
        type = types.str;
        default = "password";
      };
      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Optional path to a file containing the database password. Overrides 'password'.";
      };
      name = mkOption {
        type = types.str;
        default = "crystal_forge";
      };
    };
    server = {
      enable = mkEnableOption "Enable the Crystal Forge Server";
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
      };
      port = mkOption {
        type = types.port;
        default = 3000;
      };
    };
    client = {
      enable = mkEnableOption "Enable the Crystal Forge Agent";
      server_host = mkOption {
        type = types.str;
        default = "reckless";
      };
      server_port = mkOption {
        type = types.port;
        default = 3000;
      };
    };
    flakes = {
      watched = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name identifier for the flake";
            };
            repo_url = lib.mkOption {
              type = lib.types.str;
              description = "Repository URL of the flake";
            };
          };
        });
        default = [];
        description = "List of flakes to watch for changes";
        example = [
          {
            name = "dotfiles";
            repo_url = "git+https://gitlab.com/usmcamp0811/dotfiles";
          }
        ];
      };
    };

    systems = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            description = "System hostname";
          };
          public_key = lib.mkOption {
            type = lib.types.str;
            description = "Base64-encoded Ed25519 public key";
          };
          environment = lib.mkOption {
            type = lib.types.str;
            description = "Environment name (e.g., dev, prod, staging)";
          };
          flake_name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reference to a flake name from flakes.watched";
          };
        };
      });
      default = [];
      description = "Systems to register with Crystal Forge";
      example = [
        {
          hostname = "myhost";
          public_key = "base64encodedkey";
          environment = "production";
          flake_name = "dotfiles";
        }
      ];
    };

    environments = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Environment name (e.g., dev, prod, staging)";
          };
          description = lib.mkOption {
            type = lib.types.str;
            description = "Description of the environment";
          };
          is_active = lib.mkOption {
            type = lib.types.bool;
            description = "Whether the environment is currently active";
          };
          risk_profile = lib.mkOption {
            type = lib.types.str;
            description = "Risk profile for this environment";
          };
          compliance_level = lib.mkOption {
            type = lib.types.str;
            description = "Compliance level for this environment";
          };
        };
      });
      default = [];
      description = "List of environments for agents and evaluation";
      example = [
        {
          name = "dev";
          description = "Development environment for Crystal Forge agents and evaluation";
          is_active = true;
          risk_profile = "LOW";
          compliance_level = "NONE";
        }
      ];
    };
    role-id =
      mkOpt types.str
      config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
      config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/crystal-forge"
      "The Vault path to the KV containing the KVs that are for each database";
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
    services.crystal-forge = {
      inherit
        (cfg)
        enable
        log_level
        configPath
        database
        server
        flakes
        systems
        environments
        ;
      client = {
        inherit (cfg.client) server_port server_host enable;
        private_key = "/var/lib/crystal-forge/agent.key";
      };
    };

    systemd.services.crystal-forge-server.path = with pkgs; [
      nix
      git
    ];
    systemd.services.crystal-forge-server.serviceConfig = {
      StateDirectory = "crystal-forge";
      User = mkDefault "root";
      Group = mkDefault "root";
      ProtectSystem = mkDefault "no";
    };

    systemd.services.crystal-forge-agent.path = with pkgs; [
      # Existing
      coreutils
      zfs

      # For filesystem data (df, mount, findmnt, lsblk)
      util-linux

      # For network interface data (ip, ifconfig)
      iproute2
      nettools

      # For system info (lscpu, lsmem, dmidecode)
      pciutils
      usbutils
      dmidecode

      # For process/memory info (ps, top, free)
      procps

      # For disk info (fdisk, parted)
      parted

      # General system utilities
      systemd
      gawk
      gnused
      gnugrep
      findutils
    ];
    systemd.services.crystal-forge-agent.preStart = ''

      mkdir -p /var/lib/crystal-forge/
      cp /tmp/detsys-vault/agent.key /var/lib/crystal-forge/agent.key
    '';

    campground.services = {
      vault-agent = {
        services = {
          "crystal-forge-agent" = {
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
                  "agent.key" = {
                    text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${host} }}{{ else }}{{ .Data.data.${host} }}{{ end }}{{ end }}'';
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
}
