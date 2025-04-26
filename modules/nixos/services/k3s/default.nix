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
    package = lib.mkPackageOption pkgs "k3s_1_31" { };

    role = mkOption {
      type = types.enum [ "server" "agent" ];
      default = "server";
      description = "The role of this k3s node.";
    };

    # tokenFile = mkOption {
    #   type = types.nullOr types.path;
    #   default = null;
    #   description = "Path to the shared join token file.";
    # };

    serverAddr = mkOption {
      type = types.nullOr types.str;
      default = "";
      description = "K3s server URL (used by agents).";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags passed to k3s.";
    };

    clusterInit = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this node should store the k3s token into Vault.";
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
      mkOpt types.str "secret/campground/k0s"
        "The Vault path to the KV containing the k0s secrets.";
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
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
      tokenFile = "/var/lib/vault/k3s/k3s-token";
      serverAddr = cfg.serverAddr;
      extraFlags = mkDefault (cfg.extraFlags ++ [ "--snapshotter overlayfs" ]);
    };

    systemd.services.store-k3s-token = mkIf cfg.clusterInit {
      description = "Store K3s node-token in Vault";
      after = [
        "k3s.service"
        "vault-agent.service"
        "network-online.target"
      ];
      requires = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "store-k3s-token" ''
          set -e

          echo "Waiting for K3s to be fully ready..."

          until [ -f /var/lib/rancher/k3s/server/node-token ]; do
            sleep 5
          done

          echo "Reading K3s node-token..."
          NODE_TOKEN=$(< /var/lib/rancher/k3s/server/node-token)

          VAULT_PATH="${cfg.vault-path}"
          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME=${config.networking.hostName}

          ROLE_ID=$(cat /var/lib/vault/$HOSTNAME/role-id)
          SECRET_ID=$(cat /var/lib/vault/$HOSTNAME/secret-id)

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN=$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
          export VAULT_TOKEN

          echo "Storing K3s node-token in Vault at $VAULT_PATH"
          ${pkgs.vault}/bin/vault kv put "$VAULT_PATH" node_token="$NODE_TOKEN"

          echo "Done storing K3s token."
        '';
        RemainAfterExit = true;
      };
    };

    environment.systemPackages = [ cfg.package ];

    systemd.services.get-k3s-token = mkIf (!cfg.clusterInit) {
      description = "Get kss tokens from Vault";
      after = [
        "vault-agent.service"
        "network-online.target"
      ];
      before = [ "k3s.service" ];
      wantedBy = [
        "multi-user.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "get-k3s-tokens" ''
          set -e
          mkdir -p /var/lib/vault/k3s/
          ${pkgs.coreutils}/bin/cp  /tmp/detsys-vault/k3s-token /var/lib/vault/k3s/k3s-token
        '';

        RemainAfterExit = true;
      };
    };
    campground.services.vault-agent.services.get-k3s-token = mkIf (!cfg.clusterInit) {
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
