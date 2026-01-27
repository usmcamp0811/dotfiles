# Layer 20: Secrets
# Vault Kubernetes authentication and ClusterSecretStore
{defaults}: {
  vaultAddress ? defaults.vaultAddress,
  vaultKvPath ? defaults.vaultKvPath,
  vaultKvVersion ? defaults.vaultKvVersion,
}: [
  {
    name = "vault-auth-serviceaccount";
    namespace = "external-secrets";
    chart = "dysnix/raw";
    needs = ["external-secrets/external-secrets"];
    values = [
      {
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
      }
    ];
  }
  {
    name = "vault-cluster-secret-store";
    namespace = "kube-system";
    chart = "dysnix/raw";
    needs = [
      "external-secrets/external-secrets"
      "external-secrets/vault-auth-serviceaccount"
    ];
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
    values = [
      {
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
                  server = vaultAddress;
                  path = vaultKvPath;
                  version = vaultKvVersion;
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
      }
    ];
  }
]
