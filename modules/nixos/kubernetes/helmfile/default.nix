{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile;

  # Use pkgs.formats.yaml for proper YAML generation + a permissive YAML value type.
  yamlFormat = pkgs.formats.yaml {};

  # Helper to sort releases by layer
  sortByLayer = releases:
    lib.sort (a: b: (a.layer or 999) < (b.layer or 999)) releases;

  # Convert our Nix release definition to Helmfile YAML format
  toHelmfileRelease = release: let
    valuesList =
      if release ? valuesContent && release.valuesContent != null
      then [release.valuesContent]
      else if release ? values && release.values != null
      then release.values
      else [];

    setList =
      if release ? setValues
      then lib.mapAttrsToList (name: value: {inherit name value;}) release.setValues
      else if release ? set && release.set != null
      then release.set
      else [];

    optionalAttrs = lib.optionalAttrs;
  in
    {
      name = release.name;
      namespace = release.namespace;
      chart = release.chart;
      createNamespace = release.createNamespace or true;
      wait = release.wait or true;
      timeout = release.timeout or 300;
    }
    // optionalAttrs (release ? dependsOn && release.dependsOn != []) {needs = release.dependsOn;}
    // optionalAttrs (valuesList != [] && valuesList != [null]) {values = valuesList;}
    // optionalAttrs (setList != []) {set = setList;}
    // optionalAttrs (release ? hooks && release.hooks != []) {hooks = release.hooks;}
    // optionalAttrs (release ? atomic && release.atomic != null) {atomic = release.atomic;}
    // optionalAttrs (release ? force && release.force != null) {force = release.force;}
    // optionalAttrs (release ? recreatePods && release.recreatePods != null) {recreatePods = release.recreatePods;};

  helmfileConfig = {
    repositories = cfg.repositories;

    helmDefaults = {
      wait = true;
      timeout = 300;
      recreatePods = false;
      force = false;
      atomic = true;
    };

    releases = map toHelmfileRelease (sortByLayer cfg.releases);
  };

  helmfileYaml = yamlFormat.generate "helmfile" helmfileConfig;
in {
  options.fmf.services.k3s.helmfile = {
    enable = mkEnableOption "Use Helmfile to manage Kubernetes applications";

    concurrency = mkOption {
      type = types.int;
      default = 1;
      description = "Helmfile sync concurrency. Use 1 to avoid Helm lock conflicts.";
    };

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

          atomic = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Override helmDefaults.atomic for this release (null = use global default)";
          };

          force = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Override helmDefaults.force for this release (null = use global default)";
          };

          recreatePods = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Override helmDefaults.recreatePods for this release (null = use global default)";
          };

          valuesContent = mkOption {
            type = types.nullOr yamlFormat.type;
            default = null;
            description = "Values as a Nix value (attrset/list/scalars) that will be converted to YAML";
          };

          values = mkOption {
            type = types.nullOr (types.listOf yamlFormat.type);
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
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      helmfile
      kubernetes-helm
      kubectl
    ];

    environment.etc."helmfile/helmfile.yaml".source = helmfileYaml;

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

          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          export HELM_CACHE_HOME=/var/cache/helm
          export HELM_CONFIG_HOME=/var/lib/helm/config
          export HELM_DATA_HOME=/var/lib/helm/data

          mkdir -p /var/cache/helm /var/lib/helm/config /var/lib/helm/data

          echo "Helmfile configuration:"
          cat /etc/helmfile/helmfile.yaml

          echo ""
          echo "Applying Helmfile releases..."
          cd /etc/helmfile
          ${pkgs.helmfile}/bin/helmfile --log-level debug sync --concurrency ${toString cfg.concurrency}

          echo "Helmfile deployment complete!"
        '';
      };
    };
  };
}
