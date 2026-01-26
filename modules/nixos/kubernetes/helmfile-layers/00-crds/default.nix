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
      {
        name = "external-secrets";
        namespace = "external-secrets";
        chart = "external-secrets/external-secrets";
        layer = 0;
        dependsOn = [];
        wait = true;
        timeout = 300;
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
