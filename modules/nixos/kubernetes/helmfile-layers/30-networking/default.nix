{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."30-networking";

  # MetalLB L2Advertisement and IPAddressPool manifests
  metallbConfigManifest = pkgs.writeText "metallb-config.yaml" ''
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: ${cfg.metallb.ipPool.name}
      namespace: metallb-system
    spec:
      addresses:
      ${concatMapStringsSep "\n" (addr: "  - ${addr}") cfg.metallb.ipPool.addresses}
      autoAssign: ${if cfg.metallb.ipPool.autoAssign then "true" else "false"}
    ---
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: ${cfg.metallb.ipPool.name}-l2
      namespace: metallb-system
    spec:
      ipAddressPools:
        - ${cfg.metallb.ipPool.name}
  '';
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
    # Ensure secrets layer is enabled (though MetalLB doesn't need it currently)
    fmf.services.k3s.helmfile.layers."20-secrets".enable = true;

    fmf.services.k3s.helmfile.releases = mkIf cfg.metallb.enable [
      {
        name = "metallb";
        namespace = "metallb-system";
        chart = "metallb/metallb";
        layer = 30;
        dependsOn = ["external-secrets/external-secrets"];  # Wait for CRDs/controllers
        wait = true;
        timeout = 900;
        atomic = false;  # MetalLB can take a while
        hooks = [
          {
            events = ["postsync"];
            showlogs = true;
            command = "kubectl";
            args = ["apply" "-f" "${metallbConfigManifest}"];
          }
        ];
      }
    ];

    fmf.services.k3s.helmfile.repositories = mkIf cfg.metallb.enable [
      {
        name = "metallb";
        url = "https://metallb.github.io/metallb";
        oci = false;
      }
    ];
  };
}
