{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."10-controllers";
in {
  options.fmf.services.k3s.helmfile.layers."10-controllers" = {
    enable = mkEnableOption "Deploy controllers layer (external-secrets operator, cert-manager)";
  };

  config = mkIf cfg.enable {
    # Ensure CRDs layer is enabled
    fmf.services.k3s.helmfile.layers."00-crds".enable = true;

    fmf.services.k3s.helmfile.releases = [
      # External Secrets Operator (CRDs already installed in layer 00)
      {
        name = "external-secrets";
        namespace = "external-secrets";
        chart = "external-secrets/external-secrets";
        layer = 10;
        dependsOn = ["external-secrets/external-secrets-crds"];
        wait = true;
        timeout = 600;
        setValues = {
          installCRDs = "false"; # Already installed
          "global.cacerts.skipVerify" = "true";
        };
      }

      # Cert-manager controller + CRDs (install once; webhook is required)
      {
        name = "cert-manager";
        namespace = "cert-manager";
        chart = "jetstack/cert-manager";
        layer = 10;
        wait = true;
        timeout = 600;
        setValues = {
          installCRDs = "true";
          # Disable startupapicheck to avoid timeout issues in constrained environments
          # The webhook will still be validated by actual certificate issuance
          "startupapicheck.enabled" = "false";
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
