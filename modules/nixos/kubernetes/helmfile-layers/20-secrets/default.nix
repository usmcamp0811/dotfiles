{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."20-secrets";

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
      NEW_K8S_HOST="$(${pkgs.kubectl}/bin/kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

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
    # This is idempotent - kubectl apply will create or update
    echo "Creating/updating temporary ServiceAccount for Vault auth setup..."
    ${pkgs.kubectl}/bin/kubectl create namespace vault-init --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -
    ${pkgs.kubectl}/bin/kubectl apply -f - <<YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: vault-init
      namespace: vault-init
    YAML

    # Create token for Vault (tokens are short-lived, safe to recreate)
    echo "Creating token for vault-init ServiceAccount..."
    ${pkgs.kubectl}/bin/kubectl -n vault-init create token vault-init --duration=24h > /tmp/token.jwt

    # Get cluster CA
    echo "Reading cluster CA..."
    ${pkgs.kubectl}/bin/kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

    K8S_HOST="$(${pkgs.kubectl}/bin/kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

    # Configure Vault Kubernetes auth (this write is idempotent)
    echo "Configuring Vault Kubernetes auth..."
    ${pkgs.vault-bin}/bin/vault write auth/kubernetes/config \
      token_reviewer_jwt=@/tmp/token.jwt \
      kubernetes_host="$K8S_HOST" \
      kubernetes_ca_cert=@/tmp/ca.crt

    # Create/update Vault role (this write is idempotent)
    echo "Writing Vault Kubernetes role external-secrets..."
    ${pkgs.vault-bin}/bin/vault write auth/kubernetes/role/external-secrets \
      bound_service_account_names="vault-auth" \
      bound_service_account_namespaces="*" \
      policies="''${VAULT_POLICY:-campground}" \
      ttl=24h

    rm -f /tmp/token.jwt /tmp/ca.crt

    echo "Vault Kubernetes auth configured successfully!"
  '';
in {
  options.fmf.services.k3s.helmfile.layers."20-secrets" = {
    enable = mkEnableOption "Deploy secrets layer (Vault integration, ClusterSecretStore)";

    vaultAddress = mkOption {
      type = types.str;
      example = "http://10.8.0.3:8200";
      description = "Vault server address";
    };

    vaultKvPath = mkOption {
      type = types.str;
      default = "secret/campground/k3s";
      description = "Vault KV path for Kubernetes secrets";
    };

    vaultKvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "Vault KV version";
    };
  };

  config = mkIf cfg.enable {
    # Ensure controllers layer is enabled
    fmf.services.k3s.helmfile.layers."10-controllers".enable = true;

    # Disable the old external-secrets module to avoid conflicts
    fmf.services.k3s.modules.external-secrets.enable = lib.mkForce false;

    # Helmfile releases for Kubernetes resources
    fmf.services.k3s.helmfile.releases = [
      # vault-auth ServiceAccount in external-secrets namespace
      {
        name = "vault-auth-serviceaccount";
        namespace = "external-secrets";
        chart = "dysnix/raw";
        layer = 20;
        dependsOn = ["external-secrets/external-secrets"];
        valuesContent = {
          resources = [
            {
              apiVersion = "v1";
              kind = "ServiceAccount";
              metadata = {
                name = "vault-auth";
                namespace = "external-secrets";
              };
              automountServiceAccountToken = true;
            }
          ];
        };
      }

      # ClusterSecretStore for Vault backend
      {
        name = "vault-cluster-secret-store";
        namespace = "kube-system";
        chart = "dysnix/raw";
        layer = 20;
        dependsOn = ["external-secrets/external-secrets" "external-secrets/vault-auth-serviceaccount"];
        # Delete external-secrets webhook to work around Service routing issue
        hooks = [
          {
            events = ["presync"];
            showlogs = true;
            command = "kubectl";
            args = [
              "delete"
              "validatingwebhookconfiguration"
              "secretstore-validate"
              "--ignore-not-found=true"
            ];
          }
        ];
        valuesContent = {
          resources = [
            {
              apiVersion = "external-secrets.io/v1";
              kind = "ClusterSecretStore";
              metadata = {
                name = "vault-backend";
              };
              spec = {
                provider = {
                  vault = {
                    server = cfg.vaultAddress;
                    path = cfg.vaultKvPath;
                    version = cfg.vaultKvVersion;
                    auth = {
                      kubernetes = {
                        mountPath = "kubernetes";
                        role = "external-secrets";
                        serviceAccountRef = {
                          name = "vault-auth";
                          namespace = "external-secrets";
                        };
                      };
                    };
                  };
                };
              };
            }
          ];
        };
      }
    ];

    # Add repository for raw chart (for deploying plain Kubernetes manifests)
    fmf.services.k3s.helmfile.repositories = [
      {
        name = "dysnix";
        url = "https://dysnix.github.io/charts";
        oci = false;
      }
    ];

    # The Vault init runs as a systemd oneshot service BEFORE helmfile
    # Order: k3s → vault-k8s-init → helmfile-apply
    # This configures Vault's Kubernetes auth so helmfile can create ClusterSecretStore
    systemd.services.vault-k8s-init = mkIf config.services.k3s.clusterInit {
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
          "VAULT_ADDR=${cfg.vaultAddress}"
          "VAULT_POLICY=campground"
          "HOSTNAME=${config.networking.hostName}"
        ];
        ExecStart = "${vaultInitScript}/bin/vault-k8s-init";
      };

      # Only run on control plane nodes
      unitConfig.ConditionPathExists = "/etc/rancher/k3s/k3s.yaml";
    };
  };
}
