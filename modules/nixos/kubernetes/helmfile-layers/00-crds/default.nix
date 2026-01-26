{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."00-crds";
in {
  options.fmf.services.k3s.helmfile.layers."00-crds" = {
    enable = mkEnableOption "Deploy CRDs layer (external-secrets, cert-manager)";
  };

  config = mkIf cfg.enable {
    fmf.services.k3s.helmfile.releases = [
      # External Secrets CRDs only (no webhook, no controller)
      {
        name = "external-secrets-crds";
        namespace = "external-secrets";
        chart = "external-secrets/external-secrets";
        layer = 0;
        dependsOn = [];
        wait = true;
        timeout = 300;
        setValues = {
          installCRDs = "true";
          # Disable all components except CRDs to avoid Helm ownership conflicts
          "webhook.enabled" = "false";
          "certController.enabled" = "false";
          # Completely disable the main controller deployment
          "replicaCount" = "0";
        };
      }
    ];

    fmf.services.k3s.helmfile.repositories = [
      {
        name = "external-secrets";
        url = "https://charts.external-secrets.io";
        oci = false;
      }
      {
        name = "jetstack";
        url = "https://charts.jetstack.io";
        oci = false;
      }
    ];
  };
}
