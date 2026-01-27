# Layer 60: GitOps
# ArgoCD deployment with optional ingress configuration
{
  lib,
  defaults,
}: {
  argocdIngressEnabled ? defaults.argocd.ingressEnabled,
  argocdIngressHost ? defaults.argocd.ingressHost,
  argocdIngressClass ? defaults.argocd.ingressClass,
}: [
  {
    name = "argocd";
    namespace = "argocd";
    chart = "argo/argo-cd";
    needs = [
      "external-secrets/external-secrets"
      "metallb-system/metallb"
      "cert-manager/cert-manager"
    ];
    wait = true;
    timeout = 600;
    values = [
      {
        server =
          {
            service = {
              type = "ClusterIP";
            };
          }
          // lib.optionalAttrs argocdIngressEnabled {
            ingress = {
              enabled = true;
              ingressClassName = argocdIngressClass;
              hostname = argocdIngressHost;
              annotations = {
                "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
                "traefik.ingress.kubernetes.io/router.tls" = "true";
              };
              tls = true;
            };
          };
      }
    ];
  }
]
