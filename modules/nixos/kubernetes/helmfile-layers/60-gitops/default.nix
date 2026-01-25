{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."60-gitops";
in {
  options.fmf.services.k3s.helmfile.layers."60-gitops" = {
    enable = mkEnableOption "Deploy GitOps layer (ArgoCD)";

    argocd = {
      enable = mkEnableOption "Deploy ArgoCD" // {default = true;};

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
          description = "Ingress class to use";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Ensure ingress, storage, and secrets layers are enabled
    fmf.services.k3s.helmfile.layers."50-ingress".enable = true;
    fmf.services.k3s.helmfile.layers."40-storage".enable = true;
    fmf.services.k3s.helmfile.layers."20-secrets".enable = true;

    fmf.services.k3s.helmfile.releases = mkIf cfg.argocd.enable [
      {
        name = "argocd";
        namespace = "argocd";
        chart = "argo/argo-cd";
        layer = 60;
        dependsOn = [
          "external-secrets/external-secrets"
          "metallb-system/metallb"
        ];
        wait = true;
        timeout = 600;
        valuesContent = {
          server = {
            service = {
              type = "ClusterIP";
            };
            ingress = mkIf cfg.argocd.ingress.enable {
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
      }
    ];

    fmf.services.k3s.helmfile.repositories = mkIf cfg.argocd.enable [
      {
        name = "argo";
        url = "https://argoproj.github.io/argo-helm";
        oci = false;
      }
    ];
  };
}
