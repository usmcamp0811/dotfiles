{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."20-secrets";

  # Vault Kubernetes auth initialization script
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

    # Ensure external-secrets ServiceAccount exists
    echo "Ensuring ServiceAccount external-secrets/vault-auth exists..."
    ${pkgs.kubectl}/bin/kubectl apply -f - <<YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: vault-auth
      namespace: external-secrets
    automountServiceAccountToken: true
    YAML

    # Create token for Vault
    echo "Creating token for external-secrets/vault-auth..."
    ${pkgs.kubectl}/bin/kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt

    # Get cluster CA
    echo "Reading cluster CA..."
    ${pkgs.kubectl}/bin/kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

    K8S_HOST="$(${pkgs.kubectl}/bin/kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

    # Configure Vault Kubernetes auth
    echo "Configuring Vault Kubernetes auth..."
    ${pkgs.vault-bin}/bin/vault write auth/kubernetes/config \
      token_reviewer_jwt=@/tmp/token.jwt \
      kubernetes_host="$K8S_HOST" \
      kubernetes_ca_cert=@/tmp/ca.crt

    # Create Vault role
    echo "Writing Vault Kubernetes role external-secrets..."
    ${pkgs.vault-bin}/bin/vault write auth/kubernetes/role/external-secrets \
      bound_service_account_names="vault-auth" \
      bound_service_account_namespaces="*" \
      policies="''${VAULT_POLICY:-campground}" \
      ttl=24h

    rm -f /tmp/token.jwt /tmp/ca.crt

    echo "Vault Kubernetes auth configured successfully!"

    # Wait for External Secrets webhook to be ready
    echo "Waiting for External Secrets webhook to be ready..."
    ${pkgs.kubectl}/bin/kubectl wait --for=condition=available --timeout=300s \
      deployment/external-secrets-webhook -n external-secrets || {
      echo "WARNING: Webhook deployment not available, checking pods..."
      ${pkgs.kubectl}/bin/kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets-webhook
    }

    # Additional wait for webhook to register
    sleep 10

    # Detect served ClusterSecretStore API version
    echo "Detecting served ClusterSecretStore API version..."
    CSS_VER="$(${pkgs.kubectl}/bin/kubectl get crd clustersecretstores.external-secrets.io \
      -o jsonpath='{range .spec.versions[?(@.served==true)]}{.name}{"\n"}{end}' | head -n1)"

    if [ -z "$CSS_VER" ]; then
      echo "ERROR: Could not determine served version for ClusterSecretStore CRD"
      ${pkgs.kubectl}/bin/kubectl get crd clustersecretstores.external-secrets.io -o yaml | head -n 120
      exit 1
    fi

    echo "ClusterSecretStore apiVersion: external-secrets.io/$CSS_VER"

    # Create ClusterSecretStore
    echo "Creating ClusterSecretStore..."
    ${pkgs.kubectl}/bin/kubectl apply -f - <<YAML
    apiVersion: external-secrets.io/$CSS_VER
    kind: ClusterSecretStore
    metadata:
      name: vault-backend
    spec:
      provider:
        vault:
          server: "''${VAULT_ADDR}"
          path: "''${VAULT_KV_PATH}"
          version: "''${VAULT_KV_VERSION}"
          auth:
            kubernetes:
              mountPath: "kubernetes"
              role: "external-secrets"
              serviceAccountRef:
                name: vault-auth
                namespace: external-secrets
    YAML

    echo "ClusterSecretStore created successfully!"
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

    # The Vault init runs as a systemd oneshot service BEFORE helmfile
    # This ensures ClusterSecretStore exists before any releases that need it
    # Runs directly on the host with access to Vault AppRole credentials
    systemd.services.vault-k8s-init = mkIf config.services.k3s.clusterInit {
      description = "Initialize Vault Kubernetes Auth and ClusterSecretStore";
      after = ["k3s.service" "network-online.target"];
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
          "VAULT_KV_PATH=${cfg.vaultKvPath}"
          "VAULT_KV_VERSION=${cfg.vaultKvVersion}"
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
