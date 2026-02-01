# path: (wherever this module lives in your flake)
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

  # Derive k3s data-dir from cfg.config if provided; otherwise fall back to k3s default.
  # Supports either "data-dir" (k3s flag style) or dataDir (camelCase).
  dataDir =
    if cfg.config ? "data-dir"
    then cfg.config."data-dir"
    else if cfg.config ? dataDir
    then cfg.config.dataDir
    else "/var/lib/rancher/k3s";

  serverStateDir = "${dataDir}/server";
  nodeTokenFile = "${serverStateDir}/node-token";
  serverTokenFile = "${serverStateDir}/token";
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
          "data-dir" = "/var/lib/rancher";
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

    gitops = {
      enable = mkEnableOption "Enable GitOps bootstrap with ArgoCD";

      package = mkOption {
        type = types.package;
        default = pkgs.fmf.kubernetes-gitops;
        description = "The gitops package containing the root app and manifests";
      };

      argocdVersion = mkOption {
        type = types.str;
        default = "7.7.0";
        description = "ArgoCD Helm chart version to install";
      };

      argocdNamespace = mkOption {
        type = types.str;
        default = "argocd";
        description = "Namespace for ArgoCD installation";
      };

      repoURL = mkOption {
        type = types.str;
        default = "https://gitlab.com/usmcamp0811/dotfiles.git";
        description = "Git repository URL for GitOps content";
      };

      targetRevision = mkOption {
        type = types.str;
        default = "nixos";
        description = "Git branch/tag to sync from";
      };

      clusterName = mkOption {
        type = types.str;
        default = "campground";
        description = "Cluster name (determines path in gitops repo)";
      };
    };
  };

  config = mkIf cfg.enable {
    # open ports for MetalLB
    networking.firewall.allowedTCPPorts = [7946];
    networking.firewall.allowedUDPPorts = [7946];
    services.k3s = {
      enable = true;
      package = cfg.package;
      clusterInit = cfg.clusterInit;
      role = cfg.role;

      # IMPORTANT: tokenFile must match the effective data-dir.
      tokenFile = mkIf (!cfg.clusterInit) nodeTokenFile;

      serverAddr = mkIf (!cfg.clusterInit) serverAddr;

      configPath = mkIf (cfg.role == "server") (
        let
          configText = lib.generators.toYAML {} cfg.config;
        in
          pkgs.writeText "k3s-config.yaml" configText
      );

      extraFlags = mkMerge [
        (mkDefault cfg.extraFlags)
        (mkIf (cfg.snapshotter != null) (mkForce ["--snapshotter" cfg.snapshotter]))
      ];

      # GitOps Bootstrap: Serve ArgoCD chart via k3s static charts
      charts = mkIf cfg.gitops.enable {
        argocd =
          pkgs.runCommand "argocd.tgz" {
            nativeBuildInputs = [pkgs.gnutar pkgs.gzip];
          } ''
            cp -r ${pkgs.nixhelmCharts.argoproj.argo-cd} argocd
            tar -czf $out -C argocd .
          '';
      };

      # GitOps Bootstrap Manifests
      manifests = mkIf cfg.gitops.enable {
        # Install ArgoCD using k3s HelmChart CRD with local chart
        "00-argocd-install".content = {
          apiVersion = "helm.cattle.io/v1";
          kind = "HelmChart";
          metadata = {
            name = "argocd";
            namespace = "kube-system";
          };
          spec = {
            chart = "https://%{KUBERNETES_API}%/static/charts/argocd.tgz";
            targetNamespace = cfg.gitops.argocdNamespace;
            createNamespace = true;
            helmVersion = "v3";
            insecureSkipTLSVerify = true;
            valuesContent = ''
              server:
                service:
                  type: ClusterIP
                ingress:
                  enabled: false
              configs:
                params:
                  server.insecure: true
              repoServer:
                livenessProbe:
                  httpGet:
                    path: /healthz
                    port: metrics
                  initialDelaySeconds: 30
                  periodSeconds: 10
                  timeoutSeconds: 5
                  failureThreshold: 5
                readinessProbe:
                  httpGet:
                    path: /healthz
                    port: metrics
                  initialDelaySeconds: 10
                  periodSeconds: 10
                  timeoutSeconds: 5
                  failureThreshold: 3
            '';
          };
        };

        # Install root Application pointing to GitOps repo
        "20-root-app" = {
          target = "root-app.yaml";
          source = cfg.gitops.package.mkRootApp {
            inherit (cfg.gitops) repoURL targetRevision clusterName;
            clusterPath = "packages/gitops/clusters/${cfg.gitops.clusterName}";
          };
        };
      };
    };

    # Add better logging for k3s service
    systemd.services.k3s = {
      environment = {
        K3S_DEBUG = "false"; # Set to "true" for verbose logging if needed
      };

      serviceConfig = {
        # Restart more aggressively on failure for joining nodes
        RestartSec = mkIf (!cfg.clusterInit) (mkForce "10s");
        StartLimitBurst = mkIf (!cfg.clusterInit) (mkForce 10);
        StartLimitIntervalSec = mkIf (!cfg.clusterInit) (mkForce "200s");
      };
    };

    # Ensure required tools are in PATH for k3s service
    systemd.services.k3s.path =
      [pkgs.coreutils pkgs.gnugrep pkgs.curl]
      ++ (optionals (cfg.snapshotter == "fuse-overlayfs") [pkgs.fuse-overlayfs pkgs.fuse3]);

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

          until [ -f /etc/rancher/k3s/k3s.yaml ]; do
            echo "Waiting for k3s kubeconfig to be created..."
            sleep 5
          done

          echo "Waiting for k3s API to be responsive..."
          MAX_RETRIES=60
          RETRY_COUNT=0
          until ${cfg.package}/bin/k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; do
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
              echo "ERROR: k3s failed to become ready after $MAX_RETRIES attempts (5 minutes)"
              exit 1
            fi
            echo "Waiting for k3s to be ready (attempt $RETRY_COUNT/$MAX_RETRIES)..."
            sleep 5
          done

          echo "K3s is ready. Getting cluster token..."

          # For HA clusters, we need the server token (node-token), not a temporary token
          # The server token allows other control plane nodes to join the etcd cluster
          if [ -f ${escapeShellArg nodeTokenFile} ]; then
            NODE_TOKEN=$(cat ${escapeShellArg nodeTokenFile})
            echo "Using server node-token from ${nodeTokenFile}"
          elif [ -f ${escapeShellArg serverTokenFile} ]; then
            NODE_TOKEN=$(cat ${escapeShellArg serverTokenFile})
            echo "Using server token from ${serverTokenFile}"
          else
            echo "ERROR: No token file found at ${nodeTokenFile} or ${serverTokenFile}"
            echo "Waiting for k3s to generate the token..."
            sleep 5
            if [ -f ${escapeShellArg nodeTokenFile} ]; then
              NODE_TOKEN=$(cat ${escapeShellArg nodeTokenFile})
              echo "Token found after waiting"
            else
              echo "ERROR: Still no token available. Cannot proceed."
              exit 1
            fi
          fi

          if [ -z "$NODE_TOKEN" ]; then
            echo "ERROR: Token is empty. Cannot proceed."
            exit 1
          fi

          echo "Token retrieved successfully (length: ''${#NODE_TOKEN})"

          echo "Reading kubeconfig..."
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

    environment.systemPackages =
      [cfg.package]
      ++ (optionals (cfg.snapshotter == "fuse-overlayfs") [pkgs.fuse-overlayfs pkgs.fuse3]);

    # Bootstrap: copy GitOps bootstrap secret to k3s manifests directory
    systemd.services.k3s.preStart = mkMerge [
      (mkIf (cfg.clusterInit && cfg.gitops.enable) (mkBefore ''
        echo "K3s PreStart: Setting up GitOps bootstrap secret..."

        # Ensure manifests directory exists
        mkdir -p ${escapeShellArg serverStateDir}/manifests

        # Wait for vault agent to provide the argocd repo secret (with timeout)
        MAX_WAIT=30
        WAIT_COUNT=0
        while [ ! -f /tmp/detsys-vault/argocd-repo-secret.yaml ] || [ ! -s /tmp/detsys-vault/argocd-repo-secret.yaml ]; do
          WAIT_COUNT=$((WAIT_COUNT + 1))
          if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
            echo "WARNING: ArgoCD repo secret not available after $MAX_WAIT seconds"
            echo "Expected file: /tmp/detsys-vault/argocd-repo-secret.yaml"
            echo "ArgoCD will not be able to sync private repositories"
            break
          fi
          echo "Waiting for vault agent to provide argocd-repo-secret (attempt $WAIT_COUNT/$MAX_WAIT)..."
          sleep 1
        done

        # Copy secret to k3s manifests directory if it exists
        if [ -f /tmp/detsys-vault/argocd-repo-secret.yaml ]; then
          cp /tmp/detsys-vault/argocd-repo-secret.yaml ${escapeShellArg serverStateDir}/manifests/10-argocd-repo-secret.yaml
          chmod 0600 ${escapeShellArg serverStateDir}/manifests/10-argocd-repo-secret.yaml
          echo "ArgoCD repo secret copied successfully"
        else
          echo "WARNING: ArgoCD repo secret not found, skipping..."
        fi
      ''))

      # Joiners: copy the Vault-rendered token into the correct data-dir-derived token path.
      (mkIf (!cfg.clusterInit) (mkBefore ''
        echo "K3s PreStart: Setting up node token for joining cluster..."

        # Ensure directories exist
        mkdir -p ${escapeShellArg serverStateDir}
        mkdir -p /var/lib/rancher/k3s/server

        # Wait for vault agent to provide the token (with timeout)
        MAX_WAIT=30
        WAIT_COUNT=0
        while [ ! -f /tmp/detsys-vault/k3s-token ] || [ ! -s /tmp/detsys-vault/k3s-token ]; do
          WAIT_COUNT=$((WAIT_COUNT + 1))
          if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
            echo "ERROR: Vault token file not available after $MAX_WAIT seconds"
            echo "Expected file: /tmp/detsys-vault/k3s-token"
            exit 1
          fi
          echo "Waiting for vault agent to provide k3s-token (attempt $WAIT_COUNT/$MAX_WAIT)..."
          sleep 1
        done

        # Copy token to both locations (for compatibility)
        cp /tmp/detsys-vault/k3s-token ${escapeShellArg nodeTokenFile}
        cp /tmp/detsys-vault/k3s-token /var/lib/rancher/k3s/server/node-token
        cp /tmp/detsys-vault/k3s-token /var/lib/rancher/server/node-token

        # Set restrictive permissions
        chmod 0600 ${escapeShellArg nodeTokenFile}
        chmod 0600 /var/lib/rancher/k3s/server/node-token
        chmod 0600 /var/lib/rancher/server/node-token

        echo "Token copied successfully from vault agent"
        echo "Token hash: $(sha256sum ${escapeShellArg nodeTokenFile} | cut -d' ' -f1)"

        # Wait for the K3s API server to be reachable before attempting to join
        echo "Checking if K3s API server is reachable at ${serverAddr}..."
        MAX_API_WAIT=60
        API_WAIT_COUNT=0
        while ! ${pkgs.curl}/bin/curl -sk --connect-timeout 2 ${serverAddr}/ping >/dev/null 2>&1; do
          API_WAIT_COUNT=$((API_WAIT_COUNT + 1))
          if [ $API_WAIT_COUNT -ge $MAX_API_WAIT ]; then
            echo "WARNING: K3s API server not reachable after $MAX_API_WAIT attempts"
            echo "Proceeding anyway - k3s will retry connection automatically"
            break
          fi
          echo "Waiting for K3s API server (attempt $API_WAIT_COUNT/$MAX_API_WAIT)..."
          sleep 2
        done

        if [ $API_WAIT_COUNT -lt $MAX_API_WAIT ]; then
          echo "K3s API server is reachable. Ready to join cluster."
        fi
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
          files =
            {
              "k3s-token" = {
                text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.node_token }}{{ else }}{{ .Data.data.node_token }}{{ end }}{{ end }}'';
                permissions = "0400";
                change-action = "restart";
              };
            }
            // (
              if cfg.gitops.enable
              then {
                # ArgoCD repository credentials (SSH deploy key)
                "argocd-repo-secret.yaml" = {
                  text = ''
                    apiVersion: v1
                    kind: Secret
                    metadata:
                      name: private-repo
                      namespace: ${cfg.gitops.argocdNamespace}
                      labels:
                        argocd.argoproj.io/secret-type: repository
                    type: Opaque
                    stringData:
                      type: git
                      url: {{ with secret "secret/campground/argocd/repo" }}{{ .Data.data.url }}{{ end }}
                      sshPrivateKey: |
                    {{ with secret "secret/campground/argocd/repo" }}{{ .Data.data.ssh_private_key | indent 4 }}{{ end }}
                  '';
                  permissions = "0600";
                  change-action = "restart";
                };
              }
              else {}
            );
        };
      };
    };
  };
}
