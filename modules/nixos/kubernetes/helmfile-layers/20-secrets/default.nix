{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."20-secrets";

  # Build the vault-k8s-init container image
  vaultInitImage = pkgs.fmf.vault-k8s-init;

  # Load the image into the local container runtime (k3s uses containerd)
  # This creates a script that loads the image
  imageLoader = pkgs.writeShellScript "load-vault-init-image" ''
    echo "Loading vault-k8s-init image into k3s containerd..."
    ${pkgs.coreutils}/bin/cat ${vaultInitImage.image} | \
      ${pkgs.k3s}/bin/k3s ctr images import -
    echo "Image loaded successfully"
  '';

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
              image: localhost/vault-k8s-init:latest
              imagePullPolicy: Never  # Image is loaded locally
              env:
                - name: VAULT_ADDR
                  value: "${cfg.vaultAddress}"
                - name: VAULT_KV_PATH
                  value: "${cfg.vaultKvPath}"
                - name: VAULT_KV_VERSION
                  value: "${cfg.vaultKvVersion}"
                - name: VAULT_POLICY
                  value: "campground"
                - name: HOSTNAME
                  value: "${config.networking.hostName}"
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

    # Disable the old external-secrets module to avoid conflicts
    fmf.services.k3s.modules.external-secrets.enable = lib.mkForce false;

    # Load the vault-k8s-init container image into k3s containerd
    systemd.services.vault-k8s-init-image-load = {
      description = "Load vault-k8s-init container image into k3s";
      after = ["k3s.service"];
      requires = ["k3s.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = imageLoader;
      };

      unitConfig.ConditionPathExists = "/etc/rancher/k3s/k3s.yaml";
    };

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
