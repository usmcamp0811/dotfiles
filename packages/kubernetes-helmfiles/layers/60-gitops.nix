# Layer 60: GitOps
# ArgoCD deployment with optional Traefik IngressRoute
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
        server = {
          service = {
            type = "ClusterIP";
          };
          ingress = {
            enabled = false;
          };
        };
      }
    ];
  }
]
++ lib.optionals argocdIngressEnabled [
  {
    name = "argocd-ingressroute";
    namespace = "argocd";
    chart = "dysnix/raw";
    needs = ["argocd/argocd" "traefik-k8s/traefik"];
    values = [
      {
        resources = [
          {
            apiVersion = "traefik.io/v1alpha1";
            kind = "IngressRoute";
            metadata = {
              name = "argocd-server";
              namespace = "argocd";
            };
            spec = {
              entryPoints = ["websecure"];
              routes = [
                {
                  kind = "Rule";
                  match = "Host(`${argocdIngressHost}`)";
                  priority = 10;
                  services = [
                    {
                      name = "argocd-server";
                      port = 443;
                      scheme = "https";
                    }
                  ];
                }
              ];
              tls = {
                certResolver = "cloudflare";
              };
            };
          }
        ];
      }
    ];
  }
]
