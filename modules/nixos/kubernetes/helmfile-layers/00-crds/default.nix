# Layer 00: CRDs
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
  cfg = config.fmf.services.k3s.helmfile.layers."00-crds";
in {
  options.fmf.services.k3s.helmfile.layers."00-crds" = {
    enable = mkEnableOption "Deploy CRDs layer (external-secrets)";
  };

  config = mkIf cfg.enable {
    # This layer is automatically included in the kubernetes-helmfiles package baseline
    # No need to add releases here - the package handles it
    fmf.services.k3s.helmfile.enable = true;
  };
}
