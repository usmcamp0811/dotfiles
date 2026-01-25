{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."40-storage";
in {
  options.fmf.services.k3s.helmfile.layers."40-storage" = {
    enable = mkEnableOption "Deploy storage layer (GlusterFS, storage classes)";
  };

  config = mkIf cfg.enable {
    # Ensure secrets layer is enabled
    fmf.services.k3s.helmfile.layers."20-secrets".enable = true;

    # GlusterFS storage is handled by the existing glusterfs-storage module
    # This layer exists for dependency ordering
    # Future: Could add CSI drivers, storage operators, etc. here

    fmf.services.k3s.helmfile.releases = [
      # Placeholder for future storage-related helm releases
    ];
  };
}
