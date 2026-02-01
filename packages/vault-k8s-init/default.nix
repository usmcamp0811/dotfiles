{
  lib,
  pkgs,
  dockerTools,
  writeShellScriptBin,
  vault-bin,
  kubectl,
  coreutils,
  gnugrep,
  ...
}: let
  # The vault-k8s-init script
  vault-k8s-init = writeShellScriptBin "vault-k8s-init" ''
    set -euo pipefail

    echo "Waiting for Vault credentials..."
    until [ -f "/var/lib/vault/$HOSTNAME/role-id" ] && [ -f "/var/lib/vault/$HOSTNAME/secret-id" ]; do
      echo "Vault credentials not found at /var/lib/vault/$HOSTNAME/, waiting..."
      sleep 5
    done

    ROLE_ID="$(cat "/var/lib/vault/$HOSTNAME/role-id")"
    SECRET_ID="$(cat "/var/lib/vault/$HOSTNAME/secret-id")"

    echo "Logging in to Vault using AppRole..."
    VAULT_TOKEN="$(${vault-bin}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
    export VAULT_TOKEN

    # Ensure external-secrets ServiceAccount exists
    echo "Ensuring ServiceAccount external-secrets/vault-auth exists..."
    ${kubectl}/bin/kubectl apply -f - <<YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: vault-auth
      namespace: external-secrets
    automountServiceAccountToken: true
    YAML

    # Create token for Vault
    echo "Creating token for external-secrets/vault-auth..."
    ${kubectl}/bin/kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt

    # Get cluster CA
    echo "Reading cluster CA..."
    ${kubectl}/bin/kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

    K8S_HOST="$(${kubectl}/bin/kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

    # Configure Vault Kubernetes auth
    echo "Configuring Vault Kubernetes auth..."
    ${vault-bin}/bin/vault write auth/kubernetes/config \
      token_reviewer_jwt=@/tmp/token.jwt \
      kubernetes_host="$K8S_HOST" \
      kubernetes_ca_cert=@/tmp/ca.crt

    # Create Vault role
    echo "Writing Vault Kubernetes role external-secrets..."
    ${vault-bin}/bin/vault write auth/kubernetes/role/external-secrets \
      bound_service_account_names="vault-auth" \
      bound_service_account_namespaces="*" \
      policies="''${VAULT_POLICY:-campground}" \
      ttl=24h

    rm -f /tmp/token.jwt /tmp/ca.crt

    echo "Vault Kubernetes auth configured successfully!"

    # Wait for External Secrets webhook to be ready
    echo "Waiting for External Secrets webhook to be ready..."
    ${kubectl}/bin/kubectl wait --for=condition=available --timeout=300s \
      deployment/external-secrets-webhook -n external-secrets || {
      echo "WARNING: Webhook deployment not available, checking pods..."
      ${kubectl}/bin/kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets-webhook
    }

    # Additional wait for webhook to register
    sleep 10

    # Detect served ClusterSecretStore API version
    echo "Detecting served ClusterSecretStore API version..."
    CSS_VER="$(${kubectl}/bin/kubectl get crd clustersecretstores.external-secrets.io \
      -o jsonpath='{range .spec.versions[?(@.served==true)]}{.name}{"\n"}{end}' | head -n1)"

    if [ -z "$CSS_VER" ]; then
      echo "ERROR: Could not determine served version for ClusterSecretStore CRD"
      ${kubectl}/bin/kubectl get crd clustersecretstores.external-secrets.io -o yaml | head -n 120
      exit 1
    fi

    echo "ClusterSecretStore apiVersion: external-secrets.io/$CSS_VER"

    # Create ClusterSecretStore
    echo "Creating ClusterSecretStore..."
    ${kubectl}/bin/kubectl apply -f - <<YAML
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
in
  vault-k8s-init
