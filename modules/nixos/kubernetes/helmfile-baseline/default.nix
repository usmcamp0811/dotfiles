# Baseline Kubernetes Infrastructure Configuration
#
# This module provides a pre-configured baseline infrastructure setup using Helmfile.
# It handles proper dependency ordering and eliminates race conditions.
#
# Usage:
#   fmf.services.k3s.helmfile.baseline = {
#     enable = true;
#     metallb.ipAddressPool.addresses = ["10.8.40.100-10.8.40.255"];
#     vault = {
#       address = "http://10.8.0.3:8200";
#       kvPath = "secret/campground/k3s";
#     };
#   };
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.baseline;

  # Split Vault path like "secret/campground/k3s"
  vaultPathParts = lib.splitString "/" cfg.vault.kvPath;
  vaultMount = lib.head vaultPathParts; # e.g. "secret"
  vaultSubPath = lib.concatStringsSep "/" (lib.tail vaultPathParts); # e.g. "campground/k3s"

  metallbAutoAssign =
    if cfg.metallb.ipAddressPool.autoAssign
    then "true"
    else "false";
in {
  options.fmf.services.k3s.helmfile.baseline = {
    enable = mkEnableOption "Deploy baseline Kubernetes infrastructure using Helmfile";

    # Layer 1: Load Balancer
    metallb = {
      enable = mkEnableOption "Deploy MetalLB" // {default = true;};

      version = mkOption {
        type = types.str;
        default = ""; # Use chart default
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

    # Layer 2: Secret Management
    externalSecrets = {
      enable = mkEnableOption "Deploy External Secrets Operator" // {default = true;};

      version = mkOption {
        type = types.str;
        default = ""; # Use chart default
        description = "External Secrets chart version";
      };
    };

    # Layer 3: Vault Integration
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
    };

    # Layer 4: Service Mesh
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

    # Layer 5: GitOps Platform
    argocd = {
      enable = mkEnableOption "Deploy ArgoCD";

      version = mkOption {
        type = types.str;
        default = ""; # Use chart default
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
    # Enable Helmfile module
    fmf.services.k3s.helmfile.enable = true;

    # Add baseline infrastructure releases
    fmf.services.k3s.helmfile.releases =
      []
      # Layer 1: MetalLB (LoadBalancer provider)
      ++ (optional cfg.metallb.enable {
        name = "metallb";
        namespace = "metallb-system";
        chart = "metallb/metallb";
        layer = 1;
        wait = true;

        # Bootstrap-friendly:
        timeout = 900;
        atomic = false;
      })
      # Layer 2: External Secrets Operator (with CRDs)
      ++ (optional cfg.externalSecrets.enable {
        name = "external-secrets";
        namespace = "external-secrets";
        chart = "external-secrets/external-secrets";
        layer = 2;
        dependsOn = optional cfg.metallb.enable "metallb-system/metallb";
        wait = true;
        timeout = 300;
        setValues = {
          installCRDs = "true";
          "global.cacerts.skipVerify" = "true";
        };
        hooks = [
          {
            events = ["postsync"];
            showlogs = true;
            command = "sh";
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
        ];
      })
      # Layer 4a: Istio Base (CRDs)
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
      # Layer 4b: Istio Control Plane
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
      # Layer 4c: Istio Ingress Gateway
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
      # Layer 4d: Istio Egress Gateway
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
      # Layer 5: ArgoCD (GitOps platform)
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
          };
        };
      });

    # Keep k3s manifests ONLY for non-CRD-backed resources / things that are safe to apply early.
    services.k3s.manifests = {
      # Vault ServiceAccount for Kubernetes auth
      vault-auth-sa = mkIf cfg.externalSecrets.enable {
        content = {
          apiVersion = "v1";
          kind = "ServiceAccount";
          metadata = {
            name = "vault-auth";
            namespace = "external-secrets";
          };
          automountServiceAccountToken = true;
        };
      };

      # ArgoCD Ingress (if enabled)
      argocd-ingress = mkIf (cfg.argocd.enable && cfg.argocd.ingress.enable) {
        content = {
          apiVersion = "networking.k8s.io/v1";
          kind = "Ingress";
          metadata = {
            name = "argocd-server";
            namespace = "argocd";
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
              "traefik.ingress.kubernetes.io/router.tls" = "true";
            };
          };
          spec = {
            ingressClassName = cfg.argocd.ingress.ingressClass;
            rules = [
              {
                host = cfg.argocd.ingress.host;
                http = {
                  paths = [
                    {
                      path = "/";
                      pathType = "Prefix";
                      backend = {
                        service = {
                          name = "argocd-server";
                          port.number = 80;
                        };
                      };
                    }
                  ];
                };
              }
            ];
            tls = [
              {
                secretName = "argocd-tls";
                hosts = [cfg.argocd.ingress.host];
              }
            ];
          };
        };
      };
    };

    # Apply MetalLB pool config AFTER Helmfile (avoids CRD race)
    systemd.services.metallb-config = mkIf (cfg.metallb.enable && config.services.k3s.clusterInit) {
      description = "Configure MetalLB IPAddressPool and L2Advertisement";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "k3s.service" "helmfile-apply.service"];
      wants = ["network-online.target"];
      requires = ["k3s.service" "helmfile-apply.service"];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "metallb-config" ''
          set -euo pipefail
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

          echo "Waiting for MetalLB CRDs..."
          until ${pkgs.k3s}/bin/k3s kubectl wait --for=condition=established --timeout=300s crd/ipaddresspools.metallb.io >/dev/null 2>&1; do
            echo "IPAddressPool CRD not ready, waiting..."
            sleep 5
          done

          echo "Applying MetalLB IPAddressPool + L2Advertisement..."
          ${pkgs.k3s}/bin/k3s kubectl apply -f - <<'YAML'
          apiVersion: metallb.io/v1beta1
          kind: IPAddressPool
          metadata:
            name: ${cfg.metallb.ipAddressPool.name}
            namespace: metallb-system
          spec:
            addresses:
          ${lib.concatMapStringsSep "\n" (a: "    - ${a}") cfg.metallb.ipAddressPool.addresses}
            autoAssign: ${metallbAutoAssign}
          ---
          apiVersion: metallb.io/v1beta1
          kind: L2Advertisement
          metadata:
            name: default
            namespace: metallb-system
          YAML

          echo "MetalLB config applied."
        '';
      };
    };

    # Configure Vault Kubernetes auth + create ClusterSecretStore AFTER external-secrets is installed
    systemd.services.vault-k8s-auth-init = mkIf (cfg.externalSecrets.enable && config.services.k3s.clusterInit) {
      description = "Configure Vault Kubernetes Authentication for External Secrets";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "k3s.service" "helmfile-apply.service"];
      wants = ["network-online.target"];
      requires = ["k3s.service" "helmfile-apply.service"];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "vault-k8s-auth-init" ''
          set -euo pipefail

          NS=external-secrets
          SA=vault-auth

          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          export VAULT_ADDR="${cfg.vault.address}"
          HOSTNAME=${config.networking.hostName}

          echo "Waiting for Vault credentials..."
          until [ -f "/var/lib/vault/$HOSTNAME/role-id" ] && [ -f "/var/lib/vault/$HOSTNAME/secret-id" ]; do
            echo "Vault credentials not found, waiting..."
            sleep 5
          done

          ROLE_ID="$(cat "/var/lib/vault/$HOSTNAME/role-id")"
          SECRET_ID="$(cat "/var/lib/vault/$HOSTNAME/secret-id")"

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN="$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
          export VAULT_TOKEN

          echo "Waiting for namespace $NS to exist..."
          until ${pkgs.k3s}/bin/k3s kubectl get ns "$NS" >/dev/null 2>&1; do
            echo "Namespace $NS not found, waiting..."
            sleep 2
          done

          echo "Waiting for serviceaccount $NS/$SA to exist..."
          until ${pkgs.k3s}/bin/k3s kubectl -n "$NS" get sa "$SA" >/dev/null 2>&1; do
            echo "ServiceAccount $NS/$SA not found, waiting..."
            sleep 2
          done

          echo "Creating token for $NS/$SA..."
          ${pkgs.k3s}/bin/k3s kubectl -n "$NS" create token "$SA" --duration=24h > /tmp/token.jwt

          echo "Reading cluster CA..."
          ${pkgs.k3s}/bin/k3s kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

          # This is already an https:// URL
          K8S_HOST="$(${pkgs.k3s}/bin/k3s kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

          echo "Configuring Vault Kubernetes auth..."
          ${pkgs.vault}/bin/vault write auth/kubernetes/config \
            token_reviewer_jwt=@/tmp/token.jwt \
            kubernetes_host="$K8S_HOST" \
            kubernetes_ca_cert=@/tmp/ca.crt

          echo "Writing Vault Kubernetes role external-secrets..."
          ${pkgs.vault}/bin/vault write auth/kubernetes/role/external-secrets \
            bound_service_account_names="$SA" \
            bound_service_account_namespaces="*" \
            policies="campground" \
            ttl=24h

          rm -f /tmp/token.jwt /tmp/ca.crt
          echo "Vault Kubernetes auth configured successfully!"
        '';
      };
    };
  };
}
