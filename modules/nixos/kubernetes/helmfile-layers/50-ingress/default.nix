{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."50-ingress";
in {
  options.fmf.services.k3s.helmfile.layers."50-ingress" = {
    enable = mkEnableOption "Deploy ingress layer (Traefik ingress controllers)";
  };

  config = mkIf cfg.enable {
    # Ensure networking and secrets layers are enabled
    fmf.services.k3s.helmfile.layers."30-networking".enable = true;
    fmf.services.k3s.helmfile.layers."20-secrets".enable = true;

    # Traefik configuration is handled by the existing traefik module
    # This layer exists for dependency ordering
    # Future: Could add Traefik helm releases here if not using the module

    fmf.services.k3s.helmfile.releases = [
      # Placeholder - Traefik is configured via fmf.services.k3s.modules.traefik
    ];
  };
}
