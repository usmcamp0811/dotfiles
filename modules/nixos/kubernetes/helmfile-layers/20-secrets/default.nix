{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."20-secrets";

  # Vault init Job manifest
  vaultInitJobManifest = pkgs.writeText "vault-init-job.yaml" ''
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: vault-init
      namespace: kube-system
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: vault-init
    rules:
      - apiGroups: [""]
        resources: ["serviceaccounts", "configmaps"]
        verbs: ["get", "create", "patch"]
      - apiGroups: [""]
        resources: ["serviceaccounts/token"]
        verbs: ["create"]
      - apiGroups: ["external-secrets.io"]
        resources: ["clustersecretstores"]
        verbs: ["get", "create", "patch"]
      - apiGroups: ["apiextensions.k8s.io"]
        resources: ["customresourcedefinitions"]
        verbs: ["get", "list"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: vault-init
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: vault-init
    subjects:
      - kind: ServiceAccount
        name: vault-init
        namespace: kube-system
    ---
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: vault-k8s-auth-init
      namespace: kube-system
    spec:
      ttlSecondsAfterFinished: 86400
      backoffLimit: 5
      template:
        spec:
          serviceAccountName: vault-init
          restartPolicy: OnFailure
          containers:
            - name: vault-init
              image: hashicorp/vault:1.15
              env:
                - name: VAULT_ADDR
                  value: "${cfg.vaultAddress}"
                - name: HOSTNAME
                  value: "${config.networking.hostName}"
              command: ["/bin/sh", "-c"]
              args:
                - |
                  set -euo pipefail

                  echo "Waiting for Vault credentials..."
                  until [ -f "/var/lib/vault/$HOSTNAME/role-id" ] && [ -f "/var/lib/vault/$HOSTNAME/secret-id" ]; do
                    echo "Vault credentials not found at /var/lib/vault/$HOSTNAME/, waiting..."
                    sleep 5
                  done

                  ROLE_ID="$(cat "/var/lib/vault/$HOSTNAME/role-id")"
                  SECRET_ID="$(cat "/var/lib/vault/$HOSTNAME/secret-id")"

                  echo "Logging in to Vault using AppRole..."
                  VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
                  export VAULT_TOKEN

                  # Ensure external-secrets ServiceAccount exists
                  echo "Ensuring ServiceAccount external-secrets/vault-auth exists..."
                  kubectl apply -f - <<YAML
                  apiVersion: v1
                  kind: ServiceAccount
                  metadata:
                    name: vault-auth
                    namespace: external-secrets
                  automountServiceAccountToken: true
                  YAML

                  # Create token for Vault
                  echo "Creating token for external-secrets/vault-auth..."
                  kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt

                  # Get cluster CA
                  echo "Reading cluster CA..."
                  kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

                  K8S_HOST="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

                  # Configure Vault Kubernetes auth
                  echo "Configuring Vault Kubernetes auth..."
                  vault write auth/kubernetes/config \
                    token_reviewer_jwt=@/tmp/token.jwt \
                    kubernetes_host="$K8S_HOST" \
                    kubernetes_ca_cert=@/tmp/ca.crt

                  # Create Vault role
                  echo "Writing Vault Kubernetes role external-secrets..."
                  vault write auth/kubernetes/role/external-secrets \
                    bound_service_account_names="vault-auth" \
                    bound_service_account_namespaces="*" \
                    policies="campground" \
                    ttl=24h

                  rm -f /tmp/token.jwt /tmp/ca.crt

                  echo "Vault Kubernetes auth configured successfully!"

                  # Wait for External Secrets webhook to be ready
                  echo "Waiting for External Secrets webhook to be ready..."
                  kubectl wait --for=condition=available --timeout=300s \
                    deployment/external-secrets-webhook -n external-secrets || true

                  # Additional wait for webhook to register
                  sleep 10

                  # Detect served ClusterSecretStore API version
                  echo "Detecting served ClusterSecretStore API version..."
                  CSS_VER="$(kubectl get crd clustersecretstores.external-secrets.io \
                    -o jsonpath='{range .spec.versions[?(@.served==true)]}{.name}{"\n"}{end}' | head -n1)"

                  if [ -z "$CSS_VER" ]; then
                    echo "ERROR: Could not determine served version for ClusterSecretStore CRD"
                    kubectl get crd clustersecretstores.external-secrets.io -o yaml | head -n 120
                    exit 1
                  fi

                  echo "ClusterSecretStore apiVersion: external-secrets.io/$CSS_VER"

                  # Create ClusterSecretStore
                  echo "Creating ClusterSecretStore..."
                  kubectl apply -f - <<YAML
                  apiVersion: external-secrets.io/$CSS_VER
                  kind: ClusterSecretStore
                  metadata:
                    name: vault-backend
                  spec:
                    provider:
                      vault:
                        server: "${cfg.vaultAddress}"
                        path: "${cfg.vaultKvPath}"
                        version: "${cfg.vaultKvVersion}"
                        auth:
                          kubernetes:
                            mountPath: "kubernetes"
                            role: "external-secrets"
                            serviceAccountRef:
                              name: vault-auth
                              namespace: external-secrets
                  YAML

                  echo "ClusterSecretStore created successfully!"
              volumeMounts:
                - name: vault-creds
                  mountPath: /var/lib/vault/${config.networking.hostName}
                  readOnly: true
          volumes:
            - name: vault-creds
              hostPath:
                path: /var/lib/vault/${config.networking.hostName}
                type: Directory
  '';

  # Script to apply the Job and wait for completion
  vaultInitScript = pkgs.writeShellScript "vault-init.sh" ''
    set -euo pipefail

    echo "Applying Vault init Job..."
    ${pkgs.kubectl}/bin/kubectl apply -f ${vaultInitJobManifest}

    echo "Waiting for Vault init Job to complete..."
    ${pkgs.kubectl}/bin/kubectl wait --for=condition=complete --timeout=600s \
      job/vault-k8s-auth-init -n kube-system || {
      echo "Job did not complete, checking status..."
      ${pkgs.kubectl}/bin/kubectl get job vault-k8s-auth-init -n kube-system -o yaml
      ${pkgs.kubectl}/bin/kubectl logs -n kube-system job/vault-k8s-auth-init --tail=100 || true
      exit 1
    }

    echo "Vault Kubernetes auth initialization complete!"
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

    # The Vault init runs as a systemd oneshot service BEFORE helmfile
    # This ensures ClusterSecretStore exists before any releases that need it
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
        ];
        ExecStart = vaultInitScript;
      };

      # Only run on control plane nodes
      unitConfig.ConditionPathExists = "/etc/rancher/k3s/k3s.yaml";
    };
  };
}
