#
# Baseline Kubernetes Infrastructure Configuration
#
# This module provides a pre-configured baseline infrastructure setup using Helmfile.
# It handles proper dependency ordering and eliminates race conditions.
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.baseline;
in {
  options.fmf.services.k3s.helmfile.baseline = {
    enable = mkEnableOption "Deploy baseline Kubernetes infrastructure using Helmfile";

    metallb = {
      enable = mkEnableOption "Deploy MetalLB" // {default = true;};

      version = mkOption {
        type = types.str;
        default = "";
        description = "MetalLB chart version";
      };

      ipAddressPool = mkOption {
        type = types.submodule ({...}: {
          options = {
            name = mkOption {
              type = types.str;
              default = "default-pool";
            };
            addresses = mkOption {
              type = types.listOf types.str;
              example = ["10.8.40.100-10.8.40.255"];
              description = "IP address ranges for MetalLB";
            };
            autoAssign = mkOption {
              type = types.bool;
              default = true;
            };
          };
        });
        description = "MetalLB IP address pool configuration";
      };
    };

    externalSecrets = {
      enable = mkEnableOption "Deploy External Secrets Operator" // {default = true;};

      version = mkOption {
        type = types.str;
        default = "";
        description = "External Secrets chart version";
      };
    };

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

      createClusterSecretStore =
        mkEnableOption "Create ClusterSecretStore for Vault" // {default = true;};

      externalSecrets = mkOption {
        type = types.listOf (types.submodule ({...}: {
          options = {
            name = mkOption {
              type = types.str;
              description = "ExternalSecret name";
            };

            namespace = mkOption {
              type = types.str;
              default = "kube-system";
              description = "Namespace for the ExternalSecret";
            };

            layer = mkOption {
              type = types.int;
              default = 3;
              description = "Deployment layer (must be >= 3, after ClusterSecretStore)";
            };

            vaultPath = mkOption {
              type = types.str;
              description = ''
                Vault KV path relative to the kvPath.
                Example: "../cloudflare" goes from secret/campground/k3s to secret/campground/cloudflare
              '';
            };

            secretName = mkOption {
              type = types.str;
              description = "Name of the Kubernetes secret to create";
            };

            refreshInterval = mkOption {
              type = types.str;
              default = "1h";
              description = "How often to refresh the secret from Vault";
            };
          };
        }));
        default = [];
        description = "List of ExternalSecrets to create from Vault";
        example = literalExpression ''
          [
            {
              name = "cloudflare-api-token";
              namespace = "kube-system";
              layer = 3;
              vaultPath = "../cloudflare";
              secretName = "cloudflare-api-token";
            }
          ]
        '';
      };
    };

    istio = {
      enable = mkEnableOption "Deploy Istio service mesh";

      version = mkOption {
        type = types.str;
        default = "1.24.2";
        description = "Istio version";
      };

      ingressGateway = {
        enable = mkEnableOption "Deploy Istio ingress gateway" // {default = true;};

        serviceType = mkOption {
          type = types.enum ["LoadBalancer" "NodePort" "ClusterIP"];
          default = "LoadBalancer";
        };

        loadBalancerIP = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "10.8.40.101";
        };
      };

      egressGateway = {
        enable = mkEnableOption "Deploy Istio egress gateway";
      };
    };

    argocd = {
      enable = mkEnableOption "Deploy ArgoCD";

      version = mkOption {
        type = types.str;
        default = "";
        description = "ArgoCD chart version";
      };

      ingress = {
        enable = mkEnableOption "Create Ingress for ArgoCD";

        host = mkOption {
          type = types.str;
          example = "argocd.k8s.example.com";
          description = "Hostname for ArgoCD ingress";
        };

        ingressClass = mkOption {
          type = types.str;
          default = "traefik";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable Helmfile module and force Helmfile to run sequentially to avoid Helm locks
    fmf.services.k3s.helmfile.enable = true;
    fmf.services.k3s.helmfile.concurrency = 1;

    # Add baseline infrastructure releases
    fmf.services.k3s.helmfile.releases =
      []
      ++ (optional cfg.externalSecrets.enable {
        name = "external-secrets";
        namespace = "external-secrets";
        chart = "external-secrets/external-secrets";
        layer = 1;
        dependsOn = [];
        wait = true;
        timeout = 300;
        setValues = {
          installCRDs = "true";
          "global.cacerts.skipVerify" = "true";
        };
        hooks =
          [
            {
              events = ["postsync"];
              showlogs = true;
              command = "bash";
              args = [
                "-c"
                ''
                  echo "Waiting for External Secrets CRDs to be established..."
                  until kubectl wait --for=condition=established --timeout=300s crd/clustersecretstores.external-secrets.io 2>/dev/null; do
                    echo "ClusterSecretStore CRD not ready, waiting..."
                    sleep 5
                  done
                  echo "ClusterSecretStore CRD is ready!"
                ''
              ];
            }
          ]
          ++ optional
          (cfg.vault.createClusterSecretStore && config.services.k3s.clusterInit)
          {
            events = ["postsync"];
            showlogs = true;
            command = "sh";
            args = [
              "-c"
              ''
                set -euo pipefail

                NS=external-secrets
                SA=vault-auth
                export VAULT_ADDR="${cfg.vault.address}"
                HOSTNAME="${config.networking.hostName}"

                echo "Waiting for Vault credentials..."
                until [ -f "/var/lib/vault/$HOSTNAME/role-id" ] && [ -f "/var/lib/vault/$HOSTNAME/secret-id" ]; do
                  echo "Vault credentials not found, waiting..."
                  sleep 5
                done

                ROLE_ID="$(cat "/var/lib/vault/$HOSTNAME/role-id")"
                SECRET_ID="$(cat "/var/lib/vault/$HOSTNAME/secret-id")"

                echo "Logging in to Vault using AppRole..."
                VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
                export VAULT_TOKEN

                # Ensure the ServiceAccount exists
                echo "Ensuring ServiceAccount $NS/$SA exists..."
                kubectl apply -f - <<YAML
                apiVersion: v1
                kind: ServiceAccount
                metadata:
                  name: $SA
                  namespace: $NS
                automountServiceAccountToken: true
                YAML

                echo "Creating token for $NS/$SA..."
                kubectl -n "$NS" create token "$SA" --duration=24h > /tmp/token.jwt

                echo "Reading cluster CA..."
                kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

                K8S_HOST="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

                echo "Configuring Vault Kubernetes auth..."
                vault write auth/kubernetes/config \
                  token_reviewer_jwt=@/tmp/token.jwt \
                  kubernetes_host="$K8S_HOST" \
                  kubernetes_ca_cert=@/tmp/ca.crt

                echo "Writing Vault Kubernetes role external-secrets..."
                vault write auth/kubernetes/role/external-secrets \
                  bound_service_account_names="$SA" \
                  bound_service_account_namespaces="*" \
                  policies="campground" \
                  ttl=24h

                rm -f /tmp/token.jwt /tmp/ca.crt
                echo "Vault Kubernetes auth configured successfully!"

                echo "Creating ClusterSecretStore for Vault..."

                # Wait for CRD to be established
                echo "Waiting for ClusterSecretStore CRD to be established..."
                until kubectl wait --for=condition=established --timeout=60s crd/clustersecretstores.external-secrets.io 2>/dev/null; do
                  echo "CRD not established yet, retrying..."
                  sleep 2
                done

                # Dynamically detect the served API versions
                echo "Detecting served ClusterSecretStore API version..."
                CSS_VER="$(kubectl get crd clustersecretstores.external-secrets.io \
                  -o jsonpath='{range .spec.versions[?(@.served==true)]}{.name}{"\n"}{end}' | head -n1)"

                if [ -z "$CSS_VER" ]; then
                  echo "ERROR: Could not determine served version for ClusterSecretStore CRD"
                  kubectl get crd clustersecretstores.external-secrets.io -o yaml | head -n 120
                  exit 1
                fi

                echo "ClusterSecretStore apiVersion: external-secrets.io/$CSS_VER"

                cat <<YAML | kubectl apply -f -
                apiVersion: external-secrets.io/$CSS_VER
                kind: ClusterSecretStore
                metadata:
                  name: vault-backend
                spec:
                  provider:
                    vault:
                      server: "${cfg.vault.address}"
                      path: "${cfg.vault.kvPath}"
                      version: "${cfg.vault.kvVersion}"
                      auth:
                        kubernetes:
                          mountPath: "kubernetes"
                          role: "external-secrets"
                          serviceAccountRef:
                            name: $SA
                            namespace: $NS
                YAML

                echo "ClusterSecretStore created successfully!"
              ''
            ];
          };
      })
      ++ (optional cfg.metallb.enable {
        name = "metallb";
        namespace = "metallb-system";
        chart = "metallb/metallb";
        layer = 2;
        dependsOn = optional cfg.externalSecrets.enable "external-secrets/external-secrets";
        wait = true;
        timeout = 900;
        atomic = false;
      })
      ++ (optional cfg.istio.enable {
        name = "istio-base";
        namespace = "istio-system";
        chart = "istio/base";
        layer = 4;
        dependsOn = optional cfg.metallb.enable "metallb-system/metallb";
        wait = true;
        timeout = 300;
        setValues = {
          "defaultRevision" = "default";
        };
      })
      ++ (optional cfg.istio.enable {
        name = "istiod";
        namespace = "istio-system";
        chart = "istio/istiod";
        layer = 4;
        dependsOn = ["istio-system/istio-base"];
        wait = true;
        timeout = 300;
        valuesContent = {
          pilot = {
            resources = {
              requests = {
                cpu = "100m";
                memory = "512Mi";
              };
            };
          };
        };
      })
      ++ (optional (cfg.istio.enable && cfg.istio.ingressGateway.enable) {
        name = "istio-ingressgateway";
        namespace = "istio-system";
        chart = "istio/gateway";
        layer = 4;
        dependsOn = ["istio-system/istiod"];
        wait = true;
        timeout = 300;
        valuesContent =
          {
            service = {
              type = cfg.istio.ingressGateway.serviceType;
            };
          }
          // (
            if cfg.istio.ingressGateway.loadBalancerIP != null
            then {service.loadBalancerIP = cfg.istio.ingressGateway.loadBalancerIP;}
            else {}
          );
      })
      ++ (optional (cfg.istio.enable && cfg.istio.egressGateway.enable) {
        name = "istio-egressgateway";
        namespace = "istio-system";
        chart = "istio/gateway";
        layer = 4;
        dependsOn = ["istio-system/istiod"];
        wait = true;
        timeout = 300;
        valuesContent = {
          service = {
            type = "ClusterIP";
          };
        };
      })
      ++ (optional cfg.argocd.enable {
        name = "argocd";
        namespace = "argocd";
        chart = "argo/argo-cd";
        layer = 5;
        dependsOn =
          (optional cfg.externalSecrets.enable "external-secrets/external-secrets")
          ++ (optional cfg.istio.enable "istio-system/istiod");
        wait = true;
        timeout = 300;
        valuesContent = {
          server = {
            service = {
              type = "ClusterIP";
            };
            ingress = mkIf (cfg.argocd.ingress.enable) {
              enabled = true;
              ingressClassName = cfg.argocd.ingress.ingressClass;
              hostname = cfg.argocd.ingress.host;
              annotations = {
                "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
                "traefik.ingress.kubernetes.io/router.tls" = "true";
              };
              tls = true;
            };
          };
        };
      })
      # Add ExternalSecrets from vault.externalSecrets configuration
      ++ (map (es: {
        name = "externalsecret-${es.name}";
        namespace = es.namespace;
        chart = "external-secrets/external-secrets";  # Reference to keep helmfile happy
        layer = es.layer;
        dependsOn = ["external-secrets/external-secrets"];
        wait = false;
        timeout = 60;
        atomic = false;
        hooks = [
          {
            events = ["presync"];
            showlogs = true;
            command = "sh";
            args = [
              "-c"
              ''
                echo "Creating ExternalSecret ${es.name} in namespace ${es.namespace}..."

                # Detect served ExternalSecret API version
                ES_VER="$(kubectl get crd externalsecrets.external-secrets.io \
                  -o jsonpath='{range .spec.versions[?(@.served==true)]}{.name}{"\n"}{end}' | head -n1)"

                if [ -z "$ES_VER" ]; then
                  echo "ERROR: Could not determine served version for ExternalSecret CRD"
                  kubectl get crd externalsecrets.external-secrets.io -o yaml | head -n 120
                  exit 1
                fi

                echo "ExternalSecret apiVersion: external-secrets.io/$ES_VER"

                kubectl apply -f - <<YAML
                apiVersion: external-secrets.io/$ES_VER
                kind: ExternalSecret
                metadata:
                  name: ${es.name}
                  namespace: ${es.namespace}
                spec:
                  refreshInterval: ${es.refreshInterval}
                  secretStoreRef:
                    name: vault-backend
                    kind: ClusterSecretStore
                  target:
                    name: ${es.secretName}
                    creationPolicy: Owner
                    deletionPolicy: Retain
                  dataFrom:
                    - extract:
                        key: ${es.vaultPath}
                YAML
                echo "ExternalSecret ${es.name} created successfully!"
              ''
            ];
          }
          {
            events = ["postsync"];
            showlogs = true;
            command = "sh";
            args = [
              "-c"
              "echo 'Skipping actual Helm install for ExternalSecret ${es.name} (managed via kubectl)'"
            ];
          }
        ];
        valuesContent = {};
      }) cfg.vault.externalSecrets);
  };
}
