# Layer 60: GitOps
# Configuration for ArgoCD
# Helmfile generation is handled by the kubernetes-helmfiles package
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
    # Ensure dependencies are enabled
    fmf.services.k3s.helmfile.layers."50-ingress".enable = true;
    fmf.services.k3s.helmfile.layers."40-storage".enable = true;
    fmf.services.k3s.helmfile.layers."20-secrets".enable = true;

    # Enable helmfile with package-based generation
    fmf.services.k3s.helmfile.enable = true;
  };
}
