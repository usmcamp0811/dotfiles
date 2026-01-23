# path: (wherever this module lives in your flake)
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.modules.external-secrets;

  # Split cfg.vault-path like "secret/campground/k3s"
  vaultPathParts = lib.splitString "/" cfg.vault-path;
  vaultMount = lib.head vaultPathParts; # e.g. "secret"
  vaultSubPath = lib.concatStringsSep "/" (lib.tail vaultPathParts); # e.g. "campground/k3s"

  # Vault wants an https://... URL for kubernetes_host
  k8sHostUrl = "https://${cfg.serverAddr}:6443";
in {
  options.fmf.services.k3s.modules.external-secrets = {
    enable = mkEnableOption "Deploy External Secrets and Vault Store";

    serverAddr = mkOption {
      type = types.nullOr types.str;
      default = "10.8.40.49";
      description = "HA Proxy IP or K3s Server IP (used by agents).";
    };

    vault-policy = mkOpt types.str "campground" "The Policy to give the `vault-auth` ServiceAccount";

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
      "Vault KV path used for your k3s secrets (also used to infer mount/path for ClusterSecretStore).";

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
    fmf.services.k3s.modules.certificates.enable = true;

    services.k3s.charts.external-secrets =
      pkgs.runCommand "external-secrets.tgz"
      {nativeBuildInputs = [pkgs.gnutar pkgs.gzip];} ''
        cp -r ${pkgs.nixhelmCharts.external-secrets.external-secrets} external-secrets
        tar -czf $out -C external-secrets .
      '';

    systemd.services.vault-k8s-init = mkIf (config.services.k3s.clusterInit) {
      description = "Configure Vault Kubernetes Auth";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "k3s.service"];
      wants = ["network-online.target"];
      requires = ["k3s.service"];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "vault-k8s-init" ''
          set -euo pipefail

          NS=external-secrets
          SA=vault-auth

          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME=${config.networking.hostName}

          ROLE_ID="$(cat /var/lib/vault/$HOSTNAME/role-id)"
          SECRET_ID="$(cat /var/lib/vault/$HOSTNAME/secret-id)"

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN="$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
          export VAULT_TOKEN

          echo "Waiting for namespace $NS to exist..."
          for i in $(seq 1 120); do
            if ${pkgs.k3s}/bin/k3s kubectl get ns "$NS" >/dev/null 2>&1; then
              break
            fi
            sleep 2
          done

          echo "Waiting for serviceaccount $NS/$SA to exist..."
          for i in $(seq 1 120); do
            if ${pkgs.k3s}/bin/k3s kubectl -n "$NS" get sa "$SA" >/dev/null 2>&1; then
              break
            fi
            sleep 2
          done

          echo "Creating token for $NS/$SA..."
          ${pkgs.k3s}/bin/k3s kubectl -n "$NS" create token "$SA" --duration=24h > /tmp/token.jwt

          echo "Reading cluster CA..."
          ${pkgs.k3s}/bin/k3s kubectl -n "$NS" get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

          echo "Configuring Vault Kubernetes auth..."
          ${pkgs.vault}/bin/vault write auth/kubernetes/config \
            token_reviewer_jwt="$(< /tmp/token.jwt)" \
            kubernetes_host="${k8sHostUrl}" \
            kubernetes_ca_cert="$(< /tmp/ca.crt)"

          echo "Writing Vault Kubernetes role external-secrets..."
          ${pkgs.vault}/bin/vault write auth/kubernetes/role/external-secrets \
            bound_service_account_names="$SA" \
            bound_service_account_namespaces="*" \
            policies="${cfg.vault-policy}" \
            ttl=24h

          rm -f /tmp/token.jwt /tmp/ca.crt
        '';
        RemainAfterExit = true;
      };
    };

    services.k3s.manifests = {
      external-secrets.content = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChart";
        metadata.name = "external-secrets";
        spec = {
          chart = "https://%{KUBERNETES_API}%/static/charts/external-secrets.tgz";
          targetNamespace = "external-secrets";
          createNamespace = true;
          helmVersion = "v3";
          insecureSkipTLSVerify = true;

          valuesContent = ''
            global:
              cacerts:
                skipVerify: true
            installCRDs: true
          '';
        };
      };

      vault-auth-sa.content = {
        apiVersion = "v1";
        kind = "ServiceAccount";
        metadata = {
          name = "vault-auth";
          namespace = "external-secrets";
        };
        automountServiceAccountToken = true;
      };

      external-secrets-vault-store.content = {
        apiVersion = "external-secrets.io/v1beta1";
        kind = "ClusterSecretStore";
        metadata.name = "vault-backend";
        spec = {
          provider.vault = {
            # FIX: use cfg.*, not config.fmf.services.k3s.*
            server = cfg.vault-address;

            # IMPORTANT:
            # For Vault KV, this is the MOUNT name, not the whole secret path.
            # With cfg.vault-path default "secret/campground/k3s", mount is "secret".
            path = vaultMount;

            version = cfg.kvVersion;

            auth.kubernetes = {
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
  };
}
