{ lib
, config
, pkgs
, ...
}:
with lib; {
  options.campground.services.k3s.modules.external-secrets.enable = mkEnableOption "Deploy External Secrets and Vault Store";

  config = mkIf config.campground.services.k3s.modules.external-secrets.enable {
    campground.services.k3s.modules.certificates.enable = true;
    services.k3s.charts.external-secrets =
      pkgs.runCommand "external-secrets.tgz"
        {
          nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
        } ''
        cp -r ${pkgs.nixhelmCharts.external-secrets.external-secrets} external-secrets
        tar -czf $out -C external-secrets .
      '';

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
            server = config.campground.services.k3s.vault-address;
            path = lib.removeSuffix "/k3s" config.campground.services.k3s.vault-path;
            version = config.campground.services.k3s.kvVersion;
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
        spec.automountServiceAccountToken = true;
      };
    };
  };
}
