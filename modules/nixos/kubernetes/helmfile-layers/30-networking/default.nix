# Layer 30: Networking
# Configuration for MetalLB load balancer
# Helmfile generation is handled by the kubernetes-helmfiles package
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."30-networking";
in {
  options.fmf.services.k3s.helmfile.layers."30-networking" = {
    enable = mkEnableOption "Deploy networking layer (MetalLB load balancer)";

    metallb = {
      enable = mkEnableOption "Deploy MetalLB" // {default = true;};

      ipPool = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              default = "default-pool";
              description = "IP address pool name";
            };

            addresses = mkOption {
              type = types.listOf types.str;
              example = ["10.8.40.100-10.8.40.255"];
              description = "IP address ranges for MetalLB";
            };

            autoAssign = mkOption {
              type = types.bool;
              default = true;
              description = "Auto-assign IPs from this pool";
            };
          };
        };
        description = "MetalLB IP address pool configuration";
      };
    };
  };

  config = mkIf cfg.enable {
    # Ensure secrets layer is enabled
    fmf.services.k3s.helmfile.layers."20-secrets".enable = true;

    # Enable helmfile with package-based generation
    fmf.services.k3s.helmfile.enable = true;
  };
}
