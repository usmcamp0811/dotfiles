{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s;

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

  # Agents join via https://<serverAddr>:6443
  serverAddrUrl = "https://${cfg.serverAddr}:6443";

  # For joiners, pick the token file that matches the role.
  effectiveJoinTokenFile =
    if cfg.role == "agent"
    then nodeTokenFile
    else serverTokenFile;

  # Helper for reading existing Vault KV JSON across v1/v2.
  jqRoleIdPath =
    if cfg.kvVersion == "v1"
    then ".data.role_id // empty"
    else ".data.data.role_id // empty";

  jqSecretIdPath =
    if cfg.kvVersion == "v1"
    then ".data.secret_id // empty"
    else ".data.data.secret_id // empty";
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
      type = types.str;
      default = "10.8.0.197";
      description = "HA Proxy IP or K3s Server IP (used by agents and joining servers).";
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
      description = "Whether this node is the initializing server and should store the k3s token and kubeconfig into Vault.";
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
      "The Vault path to the KV containing the k3s secrets.";
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
        default = "argocd-bootstrap";
        description = "Namespace for bootstrap ArgoCD installation";
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

      enableAuthentikOIDC = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Authentik OIDC authentication for ArgoCD.
          When enabled, the k3s preStart script will stage the needed OIDC Secret manifest.
          Note: If Helm also manages argocd-secret, it may overwrite keys. Prefer wiring OIDC through Helm values long-term.
          Requires vault-auth ServiceAccount to exist in external-secrets namespace.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    # open ports for MetalLB (memberlist)
    networking.firewall.allowedTCPPorts = [6443 7946];
    networking.firewall.allowedUDPPorts = [7946];

    services.k3s = {
      enable = true;
      package = cfg.package;
      clusterInit = cfg.clusterInit;
      role = cfg.role;

      # IMPORTANT: tokenFile must match the effective data-dir.
      tokenFile = mkIf (!cfg.clusterInit) effectiveJoinTokenFile;

      # Joiners talk to the server endpoint
      serverAddr = mkIf (!cfg.clusterInit) serverAddrUrl;

      configPath = mkIf (cfg.role == "server") (
        let
          configText = lib.generators.toYAML {} cfg.config;
        in
          pkgs.writeText "k3s-config.yaml" configText
      );

      # List concat, not mkMerge
      extraFlags =
        cfg.extraFlags
        ++ optionals (cfg.snapshotter != null) ["--snapshotter" cfg.snapshotter];

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
            name = "argocd-bootstrap";
            namespace = "kube-system";
          };
          spec = {
            chart = "https://%{KUBERNETES_API}%/static/charts/argocd.tgz";
            targetNamespace = cfg.gitops.argocdNamespace;
            createNamespace = true;
            valuesContent = ''
              crds:
                install: true
                keep: true
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
            clusterPath = "packages/kubernetes-gitops/clusters/${cfg.gitops.clusterName}";
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
      [pkgs.coreutils pkgs.gnugrep pkgs.curl pkgs.jq pkgs.busybox]
      ++ (optionals (cfg.snapshotter == "fuse-overlayfs") [pkgs.fuse-overlayfs pkgs.fuse3]);

    # Configure Vault Kubernetes auth for External Secrets (after k3s is running)
    systemd.services.configure-vault-k8s-auth = mkIf (cfg.clusterInit && cfg.gitops.enable && cfg.gitops.enableAuthentikOIDC) {
      description = "Configure Vault Kubernetes Auth for External Secrets";
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
        ExecStart = pkgs.writeShellScript "configure-vault-k8s-auth" ''
          set -euo pipefail

          echo "Configuring Vault Kubernetes auth for External Secrets..."

          echo "Waiting for K3s API server to start..."
          MAX_K8S_WAIT=60
          K8S_WAIT_COUNT=0
          until ${cfg.package}/bin/k3s kubectl get --raw /healthz >/dev/null 2>&1; do
            K8S_WAIT_COUNT=$((K8S_WAIT_COUNT + 1))
            if [ "$K8S_WAIT_COUNT" -ge "$MAX_K8S_WAIT" ]; then
              echo "WARNING: K3s API not ready after $MAX_K8S_WAIT attempts"
              echo "Skipping Vault Kubernetes auth configuration"
              exit 0
            fi
            echo "Waiting for K3s API (attempt $K8S_WAIT_COUNT/$MAX_K8S_WAIT)..."
            sleep 2
          done
          echo "K3s API is ready!"

          echo "Waiting for external-secrets namespace and vault-auth ServiceAccount..."
          MAX_NS_WAIT=60
          NS_WAIT_COUNT=0
          until ${cfg.package}/bin/k3s kubectl get namespace external-secrets >/dev/null 2>&1 && \
                ${cfg.package}/bin/k3s kubectl get serviceaccount -n external-secrets vault-auth >/dev/null 2>&1; do
            NS_WAIT_COUNT=$((NS_WAIT_COUNT + 1))
            if [ "$NS_WAIT_COUNT" -ge "$MAX_NS_WAIT" ]; then
              echo "WARNING: external-secrets namespace or vault-auth ServiceAccount not found after $MAX_NS_WAIT attempts"
              echo "Skipping Vault Kubernetes auth configuration - it will be retried on next k3s restart"
              exit 0
            fi
            echo "Waiting for external-secrets resources (attempt $NS_WAIT_COUNT/$MAX_NS_WAIT)..."
            sleep 2
          done
          echo "external-secrets namespace and vault-auth ServiceAccount found!"

          echo "Creating ClusterRoleBinding for vault-auth..."
          ${cfg.package}/bin/k3s kubectl create clusterrolebinding vault-auth-delegator \
            --clusterrole=system:auth-delegator \
            --serviceaccount=external-secrets:vault-auth \
            --dry-run=client -o yaml | ${cfg.package}/bin/k3s kubectl apply -f - \
            || echo "ClusterRoleBinding may already exist"

          echo "Logging in to Vault using AppRole..."
          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME=${escapeShellArg config.networking.hostName}
          ROLE_ID="$(cat "/var/lib/vault/${config.networking.hostName}/role-id")"
          SECRET_ID="$(cat "/var/lib/vault/${config.networking.hostName}/secret-id")"
          VAULT_TOKEN="$(${pkgs.vault-bin}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
          export VAULT_TOKEN

          echo "Creating token for vault-auth ServiceAccount..."
          ${cfg.package}/bin/k3s kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt

          echo "Reading cluster CA..."
          ${cfg.package}/bin/k3s kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

          echo "Configuring Vault Kubernetes auth backend..."
          ${pkgs.vault-bin}/bin/vault write auth/kubernetes/config \
            token_reviewer_jwt=@/tmp/token.jwt \
            kubernetes_host="${serverAddrUrl}" \
            kubernetes_ca_cert=@/tmp/ca.crt \
            disable_iss_validation=true \
            || echo "WARNING: Failed to configure Vault Kubernetes auth"

          echo "Creating Vault Kubernetes role for external-secrets..."
          ${pkgs.vault-bin}/bin/vault write auth/kubernetes/role/external-secrets \
            bound_service_account_names="vault-auth" \
            bound_service_account_namespaces="*" \
            policies="campground" \
            ttl=24h \
            || echo "WARNING: Failed to create Vault Kubernetes role"

          rm -f /tmp/token.jwt /tmp/ca.crt
          echo "Vault Kubernetes auth configuration complete!"
        '';
        RemainAfterExit = true;
      };
    };

    systemd.services.store-k3s-token = mkIf cfg.clusterInit {
      description = "Store K3s join token and kubeconfig in Vault";
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

          echo "Waiting for K3s to be fully ready..."

          until [ -f /etc/rancher/k3s/k3s.yaml ]; do
            echo "Waiting for k3s kubeconfig to be created..."
            sleep 5
          done

          echo "Waiting for k3s API to be responsive..."
          MAX_RETRIES=60
          RETRY_COUNT=0
          until ${cfg.package}/bin/k3s kubectl get nodes 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q " Ready"; do
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
              echo "ERROR: k3s failed to become ready after $MAX_RETRIES attempts"
              exit 1
            fi
            echo "Waiting for k3s to be ready (attempt $RETRY_COUNT/$MAX_RETRIES)..."
            sleep 5
          done

          echo "K3s is ready. Getting cluster token..."

          if [ -f ${escapeShellArg nodeTokenFile} ]; then
            NODE_TOKEN="$(cat ${escapeShellArg nodeTokenFile})"
            echo "Using server node-token from ${nodeTokenFile}"
          elif [ -f ${escapeShellArg serverTokenFile} ]; then
            NODE_TOKEN="$(cat ${escapeShellArg serverTokenFile})"
            echo "Using server token from ${serverTokenFile}"
          else
            echo "ERROR: No token file found at ${nodeTokenFile} or ${serverTokenFile}"
            exit 1
          fi

          if [ -z "$NODE_TOKEN" ]; then
            echo "ERROR: Token is empty. Cannot proceed."
            exit 1
          fi

          echo "Token retrieved successfully (length: ''${#NODE_TOKEN})"

          echo "Reading kubeconfig..."
          KUBECONFIG_ORIG="$(cat /etc/rancher/k3s/k3s.yaml)"
          HAPROXY_IP="${cfg.serverAddr}"
          KUBECONFIG_FIXED="$(
            printf '%s\n' "$KUBECONFIG_ORIG" \
              | ${pkgs.busybox}/bin/sed "s|127\.0\.0\.1|$HAPROXY_IP|g"
          )"

          VAULT_PATH="${cfg.vault-path}"
          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME="${config.networking.hostName}"

          ROLE_ID="$(cat "/var/lib/vault/$HOSTNAME/role-id")"
          SECRET_ID="$(cat "/var/lib/vault/$HOSTNAME/secret-id")"

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN="$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
          export VAULT_TOKEN

          echo "Fetching existing Vault values (if any)..."
          EXISTING="$(${pkgs.vault}/bin/vault kv get -format=json "$VAULT_PATH" 2>/dev/null || echo '{}')"
          EXISTING_ROLE_ID="$(printf '%s\n' "$EXISTING" | ${pkgs.jq}/bin/jq -r ${escapeShellArg jqRoleIdPath})"
          EXISTING_SECRET_ID="$(printf '%s\n' "$EXISTING" | ${pkgs.jq}/bin/jq -r ${escapeShellArg jqSecretIdPath})"

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
      [cfg.package pkgs.busybox]
      ++ optionals (cfg.snapshotter == "fuse-overlayfs") [pkgs.fuse-overlayfs pkgs.fuse3];

    # Bootstrap: stage GitOps bootstrap secrets into k3s manifests directory (servers only)
    systemd.services.k3s.preStart = mkMerge [
      (mkIf (cfg.clusterInit && cfg.gitops.enable) (mkBefore ''
        echo "K3s PreStart: Setting up GitOps bootstrap secret..."

        mkdir -p ${escapeShellArg serverStateDir}/manifests

        MAX_WAIT=30
        WAIT_COUNT=0
        while [ ! -f /tmp/detsys-vault/argocd-repo-secret.yaml ] || [ ! -s /tmp/detsys-vault/argocd-repo-secret.yaml ]; do
          WAIT_COUNT=$((WAIT_COUNT + 1))
          if [ "$WAIT_COUNT" -ge "$MAX_WAIT" ]; then
            echo "WARNING: ArgoCD repo secret not available after $MAX_WAIT seconds"
            echo "Expected file: /tmp/detsys-vault/argocd-repo-secret.yaml"
            echo "ArgoCD will not be able to sync private repositories"
            break
          fi
          echo "Waiting for vault agent to provide argocd-repo-secret (attempt $WAIT_COUNT/$MAX_WAIT)..."
          sleep 1
        done

        if [ -f /tmp/detsys-vault/argocd-repo-secret.yaml ]; then
          cp /tmp/detsys-vault/argocd-repo-secret.yaml ${escapeShellArg serverStateDir}/manifests/10-argocd-repo-secret.yaml
          chmod 0600 ${escapeShellArg serverStateDir}/manifests/10-argocd-repo-secret.yaml
          echo "ArgoCD repo secret copied successfully"
        else
          echo "WARNING: ArgoCD repo secret not found, skipping..."
        fi

        ${optionalString cfg.gitops.enableAuthentikOIDC ''
          MAX_OIDC_WAIT=30
          OIDC_WAIT_COUNT=0
          while [ ! -f /tmp/detsys-vault/argocd-authentik-oidc.yaml ] || [ ! -s /tmp/detsys-vault/argocd-authentik-oidc.yaml ]; do
            OIDC_WAIT_COUNT=$((OIDC_WAIT_COUNT + 1))
            if [ "$OIDC_WAIT_COUNT" -ge "$MAX_OIDC_WAIT" ]; then
              echo "WARNING: ArgoCD Authentik OIDC secret manifest not available after $MAX_OIDC_WAIT seconds"
              echo "Expected file: /tmp/detsys-vault/argocd-authentik-oidc.yaml"
              echo "ArgoCD OIDC bootstrap may not work"
              break
            fi
            echo "Waiting for vault agent to provide argocd-authentik-oidc manifest (attempt $OIDC_WAIT_COUNT/$MAX_OIDC_WAIT)..."
            sleep 1
          done

          if [ -f /tmp/detsys-vault/argocd-authentik-oidc.yaml ]; then
            cp /tmp/detsys-vault/argocd-authentik-oidc.yaml ${escapeShellArg serverStateDir}/manifests/11-argocd-authentik-oidc.yaml
            chmod 0600 ${escapeShellArg serverStateDir}/manifests/11-argocd-authentik-oidc.yaml
            echo "ArgoCD Authentik OIDC manifest copied successfully"
          else
            echo "WARNING: ArgoCD Authentik OIDC manifest not found, skipping..."
          fi
        ''}
      ''))

      # Joiners: copy the Vault-rendered token into the correct data-dir-derived token path.
      (mkIf (!cfg.clusterInit) (mkBefore ''
        echo "K3s PreStart: Setting up join token..."

        mkdir -p ${escapeShellArg serverStateDir}
        mkdir -p /var/lib/rancher/k3s/server

        MAX_WAIT=30
        WAIT_COUNT=0
        while [ ! -f /tmp/detsys-vault/k3s-token ] || [ ! -s /tmp/detsys-vault/k3s-token ]; do
          WAIT_COUNT=$((WAIT_COUNT + 1))
          if [ "$WAIT_COUNT" -ge "$MAX_WAIT" ]; then
            echo "ERROR: Vault token file not available after $MAX_WAIT seconds"
            echo "Expected file: /tmp/detsys-vault/k3s-token"
            exit 1
          fi
          echo "Waiting for vault agent to provide k3s-token (attempt $WAIT_COUNT/$MAX_WAIT)..."
          sleep 1
        done

        # Copy token to the effective join token path, and also to the default path for compatibility.
        cp /tmp/detsys-vault/k3s-token ${escapeShellArg effectiveJoinTokenFile}

        # Compatibility copies
        cp /tmp/detsys-vault/k3s-token /var/lib/rancher/k3s/server/node-token
        cp /tmp/detsys-vault/k3s-token /var/lib/rancher/k3s/server/token

        chmod 0600 ${escapeShellArg effectiveJoinTokenFile}
        chmod 0600 /var/lib/rancher/k3s/server/node-token
        chmod 0600 /var/lib/rancher/k3s/server/token

        echo "Token copied successfully from vault agent"
        echo "Token hash: $(sha256sum ${escapeShellArg effectiveJoinTokenFile} | cut -d' ' -f1)"

        echo "Checking if K3s API server is reachable at ${serverAddrUrl}..."
        MAX_API_WAIT=60
        API_WAIT_COUNT=0
        while ! ${pkgs.curl}/bin/curl -sk --connect-timeout 2 ${serverAddrUrl}/ping >/dev/null 2>&1; do
          API_WAIT_COUNT=$((API_WAIT_COUNT + 1))
          if [ "$API_WAIT_COUNT" -ge "$MAX_API_WAIT" ]; then
            echo "WARNING: K3s API server not reachable after $MAX_API_WAIT attempts"
            echo "Proceeding anyway - k3s will retry connection automatically"
            break
          fi
          echo "Waiting for K3s API server (attempt $API_WAIT_COUNT/$MAX_API_WAIT)..."
          sleep 2
        done

        if [ "$API_WAIT_COUNT" -lt "$MAX_API_WAIT" ]; then
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
                text = ''
                  {{ with secret "${cfg.vault-path}" -}}
                  {{- if eq "${cfg.kvVersion}" "v1" -}}
                  {{ .Data.node_token }}
                  {{- else -}}
                  {{ .Data.data.node_token }}
                  {{- end -}}
                  {{- end -}}
                '';
                permissions = "0400";
                change-action = "restart";
              };
            }
            // (
              if cfg.gitops.enable
              then {
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
            )
            // (
              if cfg.gitops.enable && cfg.gitops.enableAuthentikOIDC
              then {
                # NOTE: Applying a Secret with the same name as a Helm-managed Secret can lead to
                # reconciliation fights. This is a bootstrap convenience, not the ideal long-term wiring.
                "argocd-authentik-oidc.yaml" = {
                  text = ''
                    apiVersion: v1
                    kind: Secret
                    metadata:
                      name: argocd-secret
                      namespace: ${cfg.gitops.argocdNamespace}
                    type: Opaque
                    stringData:
                      oidc.authentik.clientId: {{ with secret "secret/campground/argocd" }}{{ .Data.data.OIDC_CLIENT_ID }}{{ end }}
                      oidc.authentik.clientSecret: {{ with secret "secret/campground/argocd" }}{{ .Data.data.OIDC_CLIENT_SECRET }}{{ end }}
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
