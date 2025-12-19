{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.modules.external-secrets;
in {
  options.fmf.services.k3s.modules.external-secrets = {
    enable = mkEnableOption "Deploy External Secrets and Vault Store";
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
  };

  config = mkIf config.fmf.services.k3s.modules.external-secrets.enable {
    fmf.services.k3s.modules.certificates.enable = true;
    services.k3s.charts.external-secrets =
      pkgs.runCommand "external-secrets.tgz"
      {
        nativeBuildInputs = [pkgs.gnutar pkgs.gzip];
      } ''
        cp -r ${pkgs.nixhelmCharts.external-secrets.external-secrets} external-secrets
        tar -czf $out -C external-secrets .
      '';

    # systemd.services.vault-k8s-init = mkIf (config.services.k3s.clusterInit) {
    #   description = "Configure Vault Kubernetes Auth";
    #   wantedBy = ["multi-user.target"];
    #   after = ["network.target" "k3s.service"];
    #   requires = ["k3s.service"];
    #
    #   serviceConfig = {
    #     Type = "oneshot";
    #     User = "root";
    #     ExecStart = pkgs.writeShellScript "vault-k8s-init" ''
    #       set -e
    #
    #       K8S_HOST=${config.services.k3s.serverAddr}
    #       NS=external-secrets
    #       SA=vault-auth
    #
    #       VAULT_PATH="${cfg.vault-path}"
    #       export VAULT_ADDR="${cfg.vault-address}"
    #       HOSTNAME=${config.networking.hostName}
    #
    #       ROLE_ID=$(cat /var/lib/vault/$HOSTNAME/role-id)
    #       SECRET_ID=$(cat /var/lib/vault/$HOSTNAME/secret-id)
    #
    #       echo "Logging in to Vault using AppRole..."
    #       VAULT_TOKEN=$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
    #       export VAULT_TOKEN
    #
    #       ${pkgs.k3s}/bin/k3s kubectl -n $NS create token $SA --duration=24h > /tmp/token.jwt
    #       ${pkgs.k3s}/bin/k3s kubectl -n $NS get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt
    #
    #       ${pkgs.vault}/bin/vault write auth/kubernetes/config \
    #         token_reviewer_jwt="$(< /tmp/token.jwt)" \
    #         kubernetes_host="$K8S_HOST" \
    #         kubernetes_ca_cert="$(< /tmp/ca.crt)"
    #
    #       ${pkgs.vault}/bin/vault write auth/kubernetes/role/external-secrets \
    #         bound_service_account_names="$SA" \
    #         bound_service_account_namespaces="*" \
    #         policies=${cfg.vault-policy} \
    #         ttl=24h
    #       rm -rf /tmp/token.jwt /tmp/ca.crt
    #     '';
    #     RemainAfterExit = true;
    #   };
    # };
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

      external-secrets-vault-store.content = {
        apiVersion = "external-secrets.io/v1beta1";
        kind = "ClusterSecretStore";
        metadata.name = "vault-backend";
        spec = {
          provider.vault = {
            server = config.fmf.services.k3s.vault-address;
            path = lib.removeSuffix "/k3s" config.fmf.services.k3s.vault-path;
            version = config.fmf.services.k3s.kvVersion;
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

      vault-auth-sa.content = {
        apiVersion = "v1";
        kind = "ServiceAccount";
        metadata = {
          name = "vault-auth";
          namespace = "external-secrets";
        };
        automountServiceAccountToken = true;
      };
    };
  };
}
