{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile;

  # Helper to sort releases by layer
  sortByLayer = releases:
    lib.sort (a: b: (a.layer or 999) < (b.layer or 999)) releases;

  # Convert our Nix release definition to Helmfile YAML format
  toHelmfileRelease = release: let
    # Build the needs list from dependsOn
    needsList =
      if release ? dependsOn
      then release.dependsOn
      else [];

    # Build values list from valuesContent attrset - filter out nulls
    valuesList =
      if release ? valuesContent && release.valuesContent != null
      then [release.valuesContent]
      else if release ? values && release.values != null then release.values else [];

    # Build set list from setValues attrset
    setList =
      if release ? setValues
      then lib.mapAttrsToList (name: value: {inherit name value;}) release.setValues
      else if release ? set then release.set else [];

    baseRelease = {
      name = release.name;
      namespace = release.namespace;
      chart = release.chart;
      createNamespace = release.createNamespace or true;
      wait = release.wait or true;
      timeout = release.timeout or 300;
    };

    withNeeds =
      if needsList != []
      then baseRelease // {needs = needsList;}
      else baseRelease;

    withValues =
      if valuesList != [] && valuesList != [null]
      then withNeeds // {values = valuesList;}
      else withNeeds;

    withSet =
      if setList != []
      then withValues // {set = setList;}
      else withValues;

    withHooks =
      if release ? hooks && release.hooks != []
      then withSet // {hooks = release.hooks;}
      else withSet;
  in
    withHooks;

  # Generate the complete helmfile configuration
  helmfileConfig = {
    repositories = cfg.repositories;

    # Global defaults for all releases
    helmDefaults = {
      wait = true;
      timeout = 300;
      recreatePods = false;
      force = false;
      atomic = true;
    };

    # Convert and sort releases by layer
    releases = map toHelmfileRelease (sortByLayer cfg.releases);
  };

  # Use pkgs.formats.yaml for proper YAML generation
  yamlFormat = pkgs.formats.yaml {};
  helmfileYaml = yamlFormat.generate "helmfile" helmfileConfig;
in {
  options.fmf.services.k3s.helmfile = {
    enable = mkEnableOption "Use Helmfile to manage Kubernetes applications";

    releases = mkOption {
      type = types.listOf (types.submodule ({...}: {
        options = {
          name = mkOption {
            type = types.str;
            description = "Release name";
          };

          namespace = mkOption {
            type = types.str;
            description = "Namespace for the release";
          };

          chart = mkOption {
            type = types.str;
            description = "Chart reference (repo/chart or path)";
          };

          layer = mkOption {
            type = types.int;
            default = 999;
            description = ''
              Deployment layer for ordering. Lower numbers deploy first.
              Recommended layers:
                1 - Infrastructure (MetalLB)
                2 - Operators with CRDs (External Secrets, Cert-Manager)
                3 - Stores and Secrets (ClusterSecretStore)
                4 - Ingress/Service Mesh (Traefik, Istio)
                5 - GitOps Platform (ArgoCD)
            '';
          };

          dependsOn = mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              List of releases this depends on in "namespace/release-name" format.
              Example: ["external-secrets/external-secrets", "metallb-system/metallb"]
            '';
          };

          createNamespace = mkOption {
            type = types.bool;
            default = true;
            description = "Create namespace if it doesn't exist";
          };

          wait = mkOption {
            type = types.bool;
            default = true;
            description = "Wait for resources to be ready before marking release as successful";
          };

          timeout = mkOption {
            type = types.int;
            default = 300;
            description = "Timeout in seconds for waiting";
          };

          valuesContent = mkOption {
            type = types.nullOr types.attrs;
            default = null;
            description = "Values as a Nix attrset (will be converted to YAML)";
          };

          values = mkOption {
            type = types.nullOr (types.listOf types.attrs);
            default = null;
            description = "List of value sets (raw helmfile format)";
          };

          setValues = mkOption {
            type = types.attrs;
            default = {};
            description = ''
              Key-value pairs to set via --set flag.
              Example: { "image.tag" = "v1.0.0"; "installCRDs" = "true"; }
            '';
          };

          set = mkOption {
            type = types.nullOr (types.listOf types.attrs);
            default = null;
            description = "List of set values (raw helmfile format)";
          };

          hooks = mkOption {
            type = types.listOf types.attrs;
            default = [];
            description = "Helmfile hooks for this release";
          };
        };
      }));
      default = [];
      description = "List of Helm releases to manage with Helmfile";
    };

    repositories = mkOption {
      type = types.listOf (types.submodule ({...}: {
        options = {
          name = mkOption {
            type = types.str;
            description = "Repository name";
          };

          url = mkOption {
            type = types.str;
            description = "Repository URL";
          };

          oci = mkOption {
            type = types.bool;
            default = false;
            description = "Whether this is an OCI registry";
          };
        };
      }));
      default = [
        {
          name = "external-secrets";
          url = "https://charts.external-secrets.io";
        }
        {
          name = "argo";
          url = "https://argoproj.github.io/argo-helm";
        }
        {
          name = "traefik";
          url = "https://helm.traefik.io/traefik";
        }
        {
          name = "istio";
          url = "https://istio-release.storage.googleapis.com/charts";
        }
        {
          name = "metallb";
          url = "https://metallb.github.io/metallb";
        }
      ];
      description = "Helm chart repositories";
    };

    baselineInfrastructure = {
      enable = mkEnableOption "Deploy baseline Kubernetes infrastructure via Helmfile";

      metallb = {
        enable = mkEnableOption "Deploy MetalLB" // {default = true;};

        ipAddressPool = mkOption {
          type = types.submodule ({...}: {
            options = {
              name = mkOption {
                type = types.str;
                default = "default-pool";
              };
              addresses = mkOption {
                type = types.listOf types.str;
                example = ["10.8.40.100-10.8.40.255"];
              };
              autoAssign = mkOption {
                type = types.bool;
                default = true;
              };
            };
          });
          description = "MetalLB IP address pool configuration";
        };
      };

      externalSecrets = {
        enable = mkEnableOption "Deploy External Secrets Operator" // {default = true;};
      };

      argocd = {
        enable = mkEnableOption "Deploy ArgoCD" // {default = true;};
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      helmfile
      kubernetes-helm
      kubectl
    ];

    # Generate helmfile.yaml from Nix
    environment.etc."helmfile/helmfile.yaml".source = helmfileYaml;

    # Also write it to a readable location for debugging
    environment.etc."helmfile/helmfile.yaml.debug".text = ''
      # Generated Helmfile Configuration
      # This file is generated from your NixOS configuration
      # Location: fmf.services.k3s.helmfile
      # See /etc/helmfile/helmfile.yaml for the actual YAML file used by helmfile
    '';

    # SystemD service to apply helmfile
    systemd.services.helmfile-apply = {
      description = "Apply Helmfile releases to Kubernetes";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "k3s.service"];
      wants = ["network-online.target"];
      requires = ["k3s.service"];

      path = with pkgs; [
        kubernetes-helm
        kubectl
        git
        gnutar
        gzip
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "helmfile-apply" ''
          set -euo pipefail

          echo "Waiting for K3s to be ready..."
          until ${pkgs.k3s}/bin/k3s kubectl get --raw /healthz >/dev/null 2>&1; do
            echo "K3s API not ready, waiting..."
            sleep 5
          done

          echo "Waiting for K3s nodes to be ready..."
          until ${pkgs.k3s}/bin/k3s kubectl get nodes >/dev/null 2>&1; do
            echo "K3s nodes not ready, waiting..."
            sleep 5
          done

          # Set KUBECONFIG for helmfile
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          export HELM_CACHE_HOME=/var/cache/helm
          export HELM_CONFIG_HOME=/var/lib/helm/config
          export HELM_DATA_HOME=/var/lib/helm/data

          # Create helm directories
          mkdir -p /var/cache/helm /var/lib/helm/config /var/lib/helm/data

          echo "Helmfile configuration:"
          cat /etc/helmfile/helmfile.yaml

          echo ""
          echo "Applying Helmfile releases..."
          cd /etc/helmfile
          ${pkgs.helmfile}/bin/helmfile --log-level debug sync

          echo "Helmfile deployment complete!"
        '';
      };
    };

    # Add baseline infrastructure releases if enabled
    fmf.services.k3s.helmfile.releases = mkIf cfg.baselineInfrastructure.enable (
      []
      # Layer 1: MetalLB
      ++ (optional cfg.baselineInfrastructure.metallb.enable {
        name = "metallb";
        namespace = "metallb-system";
        chart = "metallb/metallb";
        layer = 1;
        wait = true;
        timeout = 300;
      })
      # Layer 2: External Secrets Operator
      ++ (optional cfg.baselineInfrastructure.externalSecrets.enable {
        name = "external-secrets";
        namespace = "external-secrets";
        chart = "external-secrets/external-secrets";
        layer = 2;
        dependsOn = optional cfg.baselineInfrastructure.metallb.enable "metallb-system/metallb";
        wait = true;
        timeout = 300;
        setValues = {
          installCRDs = "true";
          "global.cacerts.skipVerify" = "true";
        };
      })
      # Layer 5: ArgoCD
      ++ (optional cfg.baselineInfrastructure.argocd.enable {
        name = "argocd";
        namespace = "argocd";
        chart = "argo/argo-cd";
        layer = 5;
        dependsOn =
          optional cfg.baselineInfrastructure.externalSecrets.enable "external-secrets/external-secrets";
        wait = true;
        timeout = 300;
      })
    );

    # Create MetalLB IPAddressPool manifest if MetalLB baseline is enabled
    services.k3s.manifests = mkIf (cfg.baselineInfrastructure.enable && cfg.baselineInfrastructure.metallb.enable) {
      metallb-ipaddresspool.content = {
        apiVersion = "metallb.io/v1beta1";
        kind = "IPAddressPool";
        metadata = {
          name = cfg.baselineInfrastructure.metallb.ipAddressPool.name;
          namespace = "metallb-system";
        };
        spec = {
          addresses = cfg.baselineInfrastructure.metallb.ipAddressPool.addresses;
          autoAssign = cfg.baselineInfrastructure.metallb.ipAddressPool.autoAssign;
        };
      };

      metallb-l2advertisement.content = {
        apiVersion = "metallb.io/v1beta1";
        kind = "L2Advertisement";
        metadata = {
          name = "default";
          namespace = "metallb-system";
        };
      };
    };
  };
}
