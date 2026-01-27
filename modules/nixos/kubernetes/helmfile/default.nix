{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile;

  # Vault Kubernetes auth initialization script - ONLY configures Vault
  # This script is idempotent and safe to re-run
  vaultInitScript = pkgs.writeShellScriptBin "vault-k8s-init" ''
    set -euo pipefail

    echo "Waiting for Vault credentials..."
    until [ -f "/var/lib/vault/$HOSTNAME/role-id" ] && [ -f "/var/lib/vault/$HOSTNAME/secret-id" ]; do
      echo "Vault credentials not found at /var/lib/vault/$HOSTNAME/, waiting..."
      sleep 5
    done

    ROLE_ID="$(cat "/var/lib/vault/$HOSTNAME/role-id")"
    SECRET_ID="$(cat "/var/lib/vault/$HOSTNAME/secret-id")"

    echo "Logging in to Vault using AppRole..."
    VAULT_TOKEN="$(${pkgs.vault-bin}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
    export VAULT_TOKEN

    # Wait for k3s to be ready
    echo "Waiting for Kubernetes API to be ready..."
    until ${pkgs.kubectl}/bin/kubectl get nodes &>/dev/null; do
      echo "Waiting for Kubernetes API..."
      sleep 5
    done

    # Check if Vault Kubernetes auth is already configured
    echo "Checking if Vault Kubernetes auth is already configured..."
    if ${pkgs.vault-bin}/bin/vault read auth/kubernetes/config &>/dev/null; then
      echo "Vault Kubernetes auth already configured. Checking if reconfiguration is needed..."

      # Get current K8s host to see if it matches
      CURRENT_K8S_HOST="$(${pkgs.vault-bin}/bin/vault read -field=kubernetes_host auth/kubernetes/config 2>/dev/null || echo "")"
      NEW_K8S_HOST="https://kubernetes.default.svc:443"

      if [ "$CURRENT_K8S_HOST" = "$NEW_K8S_HOST" ]; then
        echo "Vault Kubernetes auth already correctly configured (host: $CURRENT_K8S_HOST). Skipping reconfiguration."

        # Still update the role in case policies changed
        echo "Updating Vault Kubernetes role external-secrets (idempotent)..."
        ${pkgs.vault-bin}/bin/vault write auth/kubernetes/role/external-secrets \
          bound_service_account_names="vault-auth" \
          bound_service_account_namespaces="*" \
          policies="''${VAULT_POLICY:-campground}" \
          ttl=24h

        echo "Vault Kubernetes auth validated successfully!"
        exit 0
      else
        echo "Kubernetes host changed from '$CURRENT_K8S_HOST' to '$NEW_K8S_HOST'. Reconfiguring..."
      fi
    fi

    # Create a temporary ServiceAccount for Vault configuration
    echo "Creating/updating temporary ServiceAccount for Vault auth setup..."
    ${pkgs.kubectl}/bin/kubectl create namespace vault-init --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -
    ${pkgs.kubectl}/bin/kubectl apply -f - <<YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: vault-init
      namespace: vault-init
    YAML

    # Create token for Vault
    echo "Creating token for vault-init ServiceAccount..."
    ${pkgs.kubectl}/bin/kubectl -n vault-init create token vault-init --duration=24h > /tmp/token.jwt

    # Get cluster CA
    echo "Reading cluster CA..."
    ${pkgs.kubectl}/bin/kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

    # Use the in-cluster Kubernetes service endpoint (reachable from pods)
    K8S_HOST="https://kubernetes.default.svc:443"

    # Configure Vault Kubernetes auth
    echo "Configuring Vault Kubernetes auth..."
    ${pkgs.vault-bin}/bin/vault write auth/kubernetes/config \
      token_reviewer_jwt=@/tmp/token.jwt \
      kubernetes_host="$K8S_HOST" \
      kubernetes_ca_cert=@/tmp/ca.crt

    # Create/update Vault role
    echo "Writing Vault Kubernetes role external-secrets..."
    ${pkgs.vault-bin}/bin/vault write auth/kubernetes/role/external-secrets \
      bound_service_account_names="vault-auth" \
      bound_service_account_namespaces="*" \
      policies="''${VAULT_POLICY:-campground}" \
      ttl=24h

    rm -f /tmp/token.jwt /tmp/ca.crt

    echo "Vault Kubernetes auth configured successfully!"
  '';

  # Build helmfile.yaml using the kubernetes-helmfiles package
  helmfileYaml = pkgs.fmf.kubernetes-helmfiles.mkBaseline {
    # Vault configuration
    vaultAddress = cfg.baseline.vault.address;
    vaultKvPath = cfg.baseline.vault.kvPath;
    vaultKvVersion = cfg.baseline.vault.kvVersion;

    # MetalLB configuration
    metallb = cfg.baseline.metallb;

    # ArgoCD configuration
    argocdIngressEnabled = cfg.baseline.argocd.ingress.enable;
    argocdIngressHost = cfg.baseline.argocd.ingress.host;
    argocdIngressClass = cfg.baseline.argocd.ingress.ingressClass;
  };
in {
  options.fmf.services.k3s.helmfile = {
    enable = mkEnableOption "Use Helmfile to manage Kubernetes applications with baseline infrastructure";

    concurrency = mkOption {
      type = types.int;
      default = 1;
      description = "Helmfile sync concurrency. Use 1 to avoid Helm lock conflicts.";
    };

    baseline = {
      # Vault / Secrets configuration (Layer 20)
      vault = {
        address = mkOption {
          type = types.str;
          example = "http://10.8.0.3:8200";
          description = "Vault server address";
        };

        kvPath = mkOption {
          type = types.str;
          default = "secret/campground/k3s";
          description = "Vault KV path for Kubernetes secrets";
        };

        kvVersion = mkOption {
          type = types.enum ["v1" "v2"];
          default = "v2";
          description = "Vault KV version";
        };

        enableK8sAuth = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Vault Kubernetes auth backend initialization";
        };
      };

      # MetalLB configuration (Layer 30)
      metallb = mkOption {
        type = types.submodule {
          options = {
            ipPool = mkOption {
              type = types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                    default = "default-pool";
                    description = "IP address pool name";
                  };

                  addresses = mkOption {
                    type = types.listOf types.str;
                    example = ["10.8.40.100-10.8.40.255"];
                    description = "IP address ranges for MetalLB";
                  };

                  autoAssign = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Auto-assign IPs from this pool";
                  };
                };
              };
              default = {};
              description = "MetalLB IP address pool configuration";
            };
          };
        };
        default = {};
        description = "MetalLB load balancer configuration";
      };

      # ArgoCD configuration (Layer 60)
      argocd = {
        ingress = {
          enable = mkEnableOption "Create Ingress for ArgoCD";

          host = mkOption {
            type = types.str;
            default = "";
            example = "argocd.k8s.example.com";
            description = "Hostname for ArgoCD ingress";
          };

          ingressClass = mkOption {
            type = types.str;
            default = "traefik-k8s";
            description = "Ingress class to use";
          };
        };
      };
    };

    # Backward compatibility: layer-based configuration
    layers = mkOption {
      type = types.attrsOf types.attrs;
      default = {};
      description = "Layer-based configuration (legacy compatibility)";
    };
  };

  config = mkIf cfg.enable {
    # Backward compatibility: map old layer config to new baseline config
    fmf.services.k3s.helmfile.baseline = {
      vault = mkIf (cfg.layers ? "20-secrets") {
        address = mkDefault (cfg.layers."20-secrets".vaultAddress or cfg.baseline.vault.address);
        kvPath = mkDefault (cfg.layers."20-secrets".vaultKvPath or cfg.baseline.vault.kvPath);
        kvVersion = mkDefault (cfg.layers."20-secrets".vaultKvVersion or cfg.baseline.vault.kvVersion);
      };

      metallb = mkIf (cfg.layers ? "30-networking") (
        mkDefault (cfg.layers."30-networking".metallb or cfg.baseline.metallb)
      );

      argocd.ingress = mkIf (cfg.layers ? "60-gitops") {
        enable = mkDefault (cfg.layers."60-gitops".argocd.ingress.enable or cfg.baseline.argocd.ingress.enable);
        host = mkDefault (cfg.layers."60-gitops".argocd.ingress.host or cfg.baseline.argocd.ingress.host);
        ingressClass = mkDefault (cfg.layers."60-gitops".argocd.ingress.ingressClass or cfg.baseline.argocd.ingress.ingressClass);
      };
    };

    environment.systemPackages = with pkgs; [
      helmfile
      kubernetes-helm
      kubectl
    ];

    environment.etc."helmfile/helmfile.yaml".source = helmfileYaml;

    # Vault Kubernetes auth initialization service
    systemd.services.vault-k8s-init = mkIf (cfg.baseline.vault.enableK8sAuth && config.services.k3s.clusterInit) {
      description = "Configure Vault Kubernetes Auth Backend";
      after = ["k3s.service" "network-online.target"];
      before = ["helmfile-apply.service"];
      requires = ["k3s.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Environment = [
          "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
          "VAULT_ADDR=${cfg.baseline.vault.address}"
          "VAULT_POLICY=campground"
          "HOSTNAME=${config.networking.hostName}"
        ];
        ExecStart = "${vaultInitScript}/bin/vault-k8s-init";
      };

      unitConfig.ConditionPathExists = "/etc/rancher/k3s/k3s.yaml";
    };

    # Helmfile apply service
    systemd.services.helmfile-apply = {
      description = "Apply Helmfile releases to Kubernetes";
      wantedBy = ["multi-user.target"];
      after =
        ["network-online.target" "k3s.service"]
        ++ optional cfg.baseline.vault.enableK8sAuth "vault-k8s-init.service";
      wants = ["network-online.target"];
      requires =
        ["k3s.service"]
        ++ optional cfg.baseline.vault.enableK8sAuth "vault-k8s-init.service";

      path = with pkgs; [
        kubernetes-helm
        kubectl
        git
        gnutar
        gzip
        bash
        coreutils
        vault-bin
        gnugrep
        gnused
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "helmfile-apply" ''
          set -euo pipefail

          echo "Waiting for K3s to be ready..."
          until ${pkgs.k3s}/bin/k3s kubectl get --raw /healthz >/dev/null 2>&1; do
            echo "K3s API not ready, waiting..."
            sleep 5
          done

          echo "Waiting for K3s nodes to be ready..."
          until ${pkgs.k3s}/bin/k3s kubectl get nodes >/dev/null 2>&1; do
            echo "K3s nodes not ready, waiting..."
            sleep 5
          done

          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          export HELM_CACHE_HOME=/var/cache/helm
          export HELM_CONFIG_HOME=/var/lib/helm/config
          export HELM_DATA_HOME=/var/lib/helm/data

          mkdir -p /var/cache/helm /var/lib/helm/config /var/lib/helm/data

          echo "Helmfile configuration:"
          cat /etc/helmfile/helmfile.yaml

          echo ""
          echo "Applying Helmfile releases..."
          cd /etc/helmfile
          ${pkgs.helmfile}/bin/helmfile --log-level debug sync --concurrency ${toString cfg.concurrency}

          echo "Helmfile deployment complete!"
        '';
      };
    };
  };
}
