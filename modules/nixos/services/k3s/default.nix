{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.k3s;
in
{
  options.campground.services.k3s = {
    enable = mkEnableOption "Enable k3s cluster";

    package = mkPackageOption pkgs "k3s_1_31" { };

    role = mkOption {
      type = types.enum [ "server" "agent" ];
      default = "server";
      description = "The role of this k3s node.";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the shared join token file.";
    };

    serverAddr = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "K3s server URL (used by agents).";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags passed to k3s.";
    };

    role-id = mkOpt types.str config.campground.services.vault-agent.settings.vault.role-id "Vault AppRole role-id path";
    secret-id = mkOpt types.str config.campground.services.vault-agent.settings.vault.secret-id "Vault AppRole secret-id path";
    vault-path = mkOpt types.str "secret/campground/k3s" "Vault path for k3s secrets";
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "Vault address";
    };
    kvVersion = mkOption {
      type = types.enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
  };

  config = mkIf cfg.enable {
    services.k3s = {
      enable = true;
      package = cfg.package;
      role = cfg.role;
      # tokenFile = mkIf (cfg.tokenFile == null && cfg.role == "agent") "/tmp/detsys-vault/k3s-token";
      serverAddr = cfg.serverAddr;
      # extraFlags = cfg.extraFlags;
    };

    environment.systemPackages = [ cfg.package ];

    systemd.services.get-k3s-token = mkIf (cfg.tokenFile == null && cfg.role == "agent") {
      description = "Get kss tokens from Vault";
      after = [
        "vault-agent.service"
        "network-online.target"
      ];
      before = [ "k3s" ];
      wantedBy = [
        "multi-user.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "get-k3s-tokens" ''
          set -e
          echo "TODO"
        '';

        RemainAfterExit = true;
      };
    };
    campground.services.vault-agent.services.get-k3s-token = mkIf (cfg.tokenFile == null && cfg.role == "agent") {
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
            "k3s-token" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.k3s_token }}{{ else }}{{ .Data.data.k3s_token }}{{ end }}{{ end }}
              '';
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
