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

  # Split cfg.vault-path like "secret/campground/k3s"
  vaultPathParts = lib.splitString "/" cfg.vault-path;
  vaultMount = lib.head vaultPathParts;
  vaultSubPath = lib.concatStringsSep "/" (lib.tail vaultPathParts);

  # KV v2 API endpoints
  vaultDataPath = "${vaultMount}/data/${vaultSubPath}";
  vaultMetadataPath = "${vaultMount}/metadata/${vaultSubPath}";
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
      "The Vault path to the KV containing the k3s secrets (logical path).";
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

      # IMPORTANT: for non-bootstrap nodes, point directly at the Vault Agent rendered token.
      tokenFile = mkIf (!cfg.clusterInit) "/tmp/detsys-vault/k3s-token";
      serverAddr = mkIf (!cfg.clusterInit) serverAddr;

      configPath = mkIf (cfg.role == "server") (
        let
          configText = lib.generators.toYAML {} cfg.config;
        in
          pkgs.writeText "k3s-config.yaml" configText
      );

      moreFlags =
        cfg.extraFlags
        ++ (optionals (cfg.snapshotter != null) ["--snapshotter" cfg.snapshotter]);
    };

    # Ensure fuse-overlayfs and fuse3 are in PATH for k3s service when requested
    systemd.services.k3s.path =
      mkIf (cfg.snapshotter == "fuse-overlayfs") [pkgs.fuse-overlayfs pkgs.fuse3];

    # If you want the tools available interactively too, keep this; otherwise you can drop it.
    environment.systemPackages =
      [cfg.package]
      ++ (optionals (cfg.snapshotter == "fuse-overlayfs") [pkgs.fuse-overlayfs pkgs.fuse3]);

    # NOTE: removed the old preStart copy into /var/lib/rancher/k3s/server/node-token,
    # because that path is server-specific and tokenFile now points to the Vault Agent output.

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
          set -euo pipefail

          echo "Waiting for kubeconfig..."
          until [ -f /etc/rancher/k3s/k3s.yaml ]; do
            echo "Waiting for k3s kubeconfig to be created..."
            sleep 5
          done

          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

          echo "Waiting for k3s API to be responsive..."
          MAX_RETRIES=60
          RETRY_COUNT=0
          until ${cfg.package}/bin/k3s kubectl get --raw='/readyz' >/dev/null 2>&1; do
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
              echo "ERROR: k3s failed readiness after $MAX_RETRIES attempts"
              exit 1
            fi
            echo "Waiting for k3s to be ready (attempt $RETRY_COUNT/$MAX_RETRIES)..."
            sleep 5
          done

          echo "Reading canonical node-token..."
          until [ -f /var/lib/rancher/k3s/server/node-token ]; do
            echo "Waiting for /var/lib/rancher/k3s/server/node-token..."
            sleep 2
          done
          NODE_TOKEN=$(< /var/lib/rancher/k3s/server/node-token)

          echo "Reading kubeconfig..."
          KUBECONFIG_ORIG=$(cat /etc/rancher/k3s/k3s.yaml)

          HAPROXY_IP="${cfg.serverAddr}"
          KUBECONFIG_FIXED=$(echo "$KUBECONFIG_ORIG" | sed "s/127.0.0.1/$HAPROXY_IP/g")

          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME=${config.networking.hostName}

          ROLE_ID=$(cat /var/lib/vault/$HOSTNAME/role-id)
          SECRET_ID=$(cat /var/lib/vault/$HOSTNAME/secret-id)

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN=$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
          export VAULT_TOKEN

          # Use API paths for KV v2 to avoid kv helper preflight.
          LOGICAL_PATH="${cfg.vault-path}"
          DATA_PATH="${vaultDataPath}"
          KV_VERSION="${cfg.kvVersion}"

          echo "Preparing payload..."
          payload="$(mktemp)"
          cleanup() { rm -f "$payload"; }
          trap cleanup EXIT

          if [ "$KV_VERSION" = "v2" ]; then
            # KV v2 expects {"data":{...}}
            ${pkgs.jq}/bin/jq -n \
              --arg node_token "$NODE_TOKEN" \
              --arg kubeconfig "$KUBECONFIG_FIXED" \
              '{data:{node_token:$node_token, kubeconfig:$kubeconfig}}' > "$payload"

            echo "Storing K3s node-token and kubeconfig in Vault at ${vaultDataPath} (logical: $LOGICAL_PATH)"
            ${pkgs.vault}/bin/vault write "${vaultDataPath}" @"$payload"
          else
            # KV v1 can take the flat object at the logical path
            ${pkgs.jq}/bin/jq -n \
              --arg node_token "$NODE_TOKEN" \
              --arg kubeconfig "$KUBECONFIG_FIXED" \
              '{node_token:$node_token, kubeconfig:$kubeconfig}' > "$payload"

            echo "Storing K3s node-token and kubeconfig in Vault at $LOGICAL_PATH"
            ${pkgs.vault}/bin/vault write "$LOGICAL_PATH" @"$payload"
          fi

          echo "Done storing K3s token and kubeconfig."
        '';
        RemainAfterExit = true;
      };
    };

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
              # IMPORTANT: for KV v2, read from the /data/ endpoint to match your policy.
              text =
                if cfg.kvVersion == "v2"
                then ''{{ with secret "${vaultDataPath}" }}{{ .Data.data.node_token }}{{ end }}''
                else ''{{ with secret "${cfg.vault-path}" }}{{ .Data.node_token }}{{ end }}'';
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
