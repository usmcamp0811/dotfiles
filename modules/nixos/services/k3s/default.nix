{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s;
  serverAddr = "https://${cfg.serverAddr}:6443";
in {
  options.fmf.services.k3s = {
    enable = mkEnableOption "Enable k3s cluster";
    package = lib.mkPackageOption pkgs "k3s" {};
    config = mkOption {
      type = types.attrs;
      default = {
        disable = ["servicelb" "traefik"];
      };
      description = "K3s Config Yaml";
      example = literalExpression ''
        {
          disable = ["servicelb"];
          clusterInit = true;
          tlsSan = [ "my-lb.example.com" "10.0.0.10" ];
          nodeName = "chesty";
        }
      '';
    };
    role = mkOption {
      type = types.enum ["server" "agent"];
      default = "server";
      description = "The role of this k3s node.";
    };

    serverAddr = mkOption {
      type = types.nullOr types.str;
      default = "10.8.0.197";
      description = "HA Proxy IP or K3s Server IP (used by agents).";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra flags passed to k3s.";
    };

    snapshotter = mkOption {
      type = types.nullOr (types.enum ["overlayfs" "fuse-overlayfs" "native"]);
      default = null;
      description = ''
        Container snapshotter to use. Set to "fuse-overlayfs" for virtiofs compatibility (e.g., MicroVMs).
        If null, k3s will use its default (overlayfs).
      '';
    };

    clusterInit = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this node should store the k3s token into Vault.";
    };

    role-id =
      mkOpt types.str
      config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
      config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/k3s"
      "The Vault path to the KV containing the k0s secrets.";
    vault-address = mkOption {
      type = types.str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    kvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
  };

  config = mkIf cfg.enable {
    services.k3s = {
      enable = true;
      package = cfg.package;
      clusterInit = cfg.clusterInit;
      role = cfg.role;
      tokenFile = mkIf (!cfg.clusterInit) "/var/lib/rancher/k3s/server/node-token";
      serverAddr = mkIf (!cfg.clusterInit) serverAddr;
      configPath = mkIf (cfg.role == "server") (
        let
          configText = lib.generators.toYAML {} cfg.config;
        in
          pkgs.writeText "k3s-config.yaml" configText
      );
      moreFlags = cfg.extraFlags ++ (optionals (cfg.snapshotter != null) ["--snapshotter" cfg.snapshotter]);
    };

    # Ensure fuse-overlayfs is in PATH for k3s service
    systemd.services.k3s.path = mkIf (cfg.snapshotter == "fuse-overlayfs") [pkgs.fuse-overlayfs];

    systemd.services.store-k3s-token = mkIf cfg.clusterInit {
      description = "Store K3s node-token and kubeconfig in Vault";
      after = [
        "k3s.service"
        "vault-agent.service"
        "network-online.target"
      ];
      wants = ["network-online.target"];
      requires = ["k3s.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "store-k3s-token" ''
          set -e

          echo "Waiting for K3s to be fully ready..."

          until [ -f /var/lib/rancher/k3s/server/node-token ] && [ -f /etc/rancher/k3s/k3s.yaml ]; do
            sleep 5
          done

          echo "Reading K3s node-token and kubeconfig..."
          NODE_TOKEN=$(< /var/lib/rancher/k3s/server/node-token)
          KUBECONFIG_ORIG=$(cat /etc/rancher/k3s/k3s.yaml)

          HAPROXY_IP="${cfg.serverAddr}"
          KUBECONFIG_FIXED=$(echo "$KUBECONFIG_ORIG" | sed "s/127.0.0.1/$HAPROXY_IP/g")

          VAULT_PATH="${cfg.vault-path}"
          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME=${config.networking.hostName}

          ROLE_ID=$(cat /var/lib/vault/$HOSTNAME/role-id)
          SECRET_ID=$(cat /var/lib/vault/$HOSTNAME/secret-id)

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN=$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
          export VAULT_TOKEN

          echo "Fetching existing Vault values (if any)..."
          EXISTING=$(${pkgs.vault}/bin/vault kv get -format=json "$VAULT_PATH" || echo '{}')
          EXISTING_ROLE_ID=$(echo "$EXISTING" | ${pkgs.jq}/bin/jq -r '.data.data.role_id // empty')
          EXISTING_SECRET_ID=$(echo "$EXISTING" | ${pkgs.jq}/bin/jq -r '.data.data.secret_id // empty')

          ARGS=(
            node_token="$NODE_TOKEN"
            kubeconfig="$KUBECONFIG_FIXED"
          )
          [ -n "$EXISTING_ROLE_ID" ] && ARGS+=("role_id=$EXISTING_ROLE_ID")
          [ -n "$EXISTING_SECRET_ID" ] && ARGS+=("secret_id=$EXISTING_SECRET_ID")

          echo "Storing K3s node-token and kubeconfig in Vault at $VAULT_PATH"
          ${pkgs.vault}/bin/vault kv put "$VAULT_PATH" "''${ARGS[@]}"

          echo "Done storing K3s token and kubeconfig."
        '';

        RemainAfterExit = true;
      };
    };

    environment.systemPackages = [cfg.package] ++ (optionals (cfg.snapshotter == "fuse-overlayfs") [pkgs.fuse-overlayfs]);
    systemd.services.k3s.preStart = mkMerge [
      (mkIf (!cfg.clusterInit) (mkBefore ''
        mkdir -p /var/lib/rancher/k3s/server
        cp /tmp/detsys-vault/k3s-token /var/lib/rancher/k3s/server/node-token
      ''))
    ];

    fmf.services.vault-agent.services.k3s = {
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
              text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.node_token }}{{ else }}{{ .Data.data.node_token }}{{ end }}{{ end }}'';
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
