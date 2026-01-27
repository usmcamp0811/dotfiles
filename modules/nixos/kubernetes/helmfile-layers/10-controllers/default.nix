# Layer 10: Controllers
# This layer is now provided by the kubernetes-helmfiles package
# This module only provides options for compatibility
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
    enable = mkEnableOption "Deploy controllers layer (cert-manager)";
  };

  config = mkIf cfg.enable {
    # Ensure CRDs layer is enabled
    fmf.services.k3s.helmfile.layers."00-crds".enable = true;

    # This layer is automatically included in the kubernetes-helmfiles package baseline
    fmf.services.k3s.helmfile.enable = true;
  };
}
