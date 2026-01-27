{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile;

  # Build helmfile.yaml using the kubernetes-helmfiles package
  # Collect configuration from layer modules
  helmfileYaml =
    if cfg.usePackage
    then
      pkgs.fmf.kubernetes-helmfiles.mkBaseline {
        # Vault configuration from 20-secrets layer
        vaultAddress = cfg.layers."20-secrets".vaultAddress or pkgs.fmf.kubernetes-helmfiles.defaults.vaultAddress;
        vaultKvPath = cfg.layers."20-secrets".vaultKvPath or pkgs.fmf.kubernetes-helmfiles.defaults.vaultKvPath;
        vaultKvVersion = cfg.layers."20-secrets".vaultKvVersion or pkgs.fmf.kubernetes-helmfiles.defaults.vaultKvVersion;

        # MetalLB configuration from 30-networking layer
        metallb = cfg.layers."30-networking".metallb or pkgs.fmf.kubernetes-helmfiles.defaults.metallb;

        # ArgoCD configuration from 60-gitops layer
        argocdIngressEnabled = cfg.layers."60-gitops".argocd.ingress.enable or false;
        argocdIngressHost = cfg.layers."60-gitops".argocd.ingress.host or pkgs.fmf.kubernetes-helmfiles.defaults.argocd.ingressHost;
        argocdIngressClass = cfg.layers."60-gitops".argocd.ingress.ingressClass or pkgs.fmf.kubernetes-helmfiles.defaults.argocd.ingressClass;
      }
    else
      # Legacy: generate from cfg.releases
      let
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

        # De-dupe repos
        repoKey = r: "${r.name}|${r.url}|${toString (r.oci or false)}";

        repositoriesDeduped =
          map (x: x.repo)
          (lib.unique
            (map (r: {
                key = repoKey r;
                repo = r;
              })
              cfg.repositories));

        helmfileConfig = {
          repositories = repositoriesDeduped;

          helmDefaults = {
            wait = true;
            timeout = 300;
            recreatePods = false;
            force = false;
            atomic = true;
          };

          releases = map toHelmfileRelease (sortByLayer cfg.releases);
        };
      in
        yamlFormat.generate "helmfile" helmfileConfig;
in {
  options.fmf.services.k3s.helmfile = {
    enable = mkEnableOption "Use Helmfile to manage Kubernetes applications";

    usePackage = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use the kubernetes-helmfiles package to generate helmfile.yaml.
        When true, helmfile is generated from layer module configuration.
        When false, uses legacy cfg.releases approach.
      '';
    };

    concurrency = mkOption {
      type = types.int;
      default = 1;
      description = "Helmfile sync concurrency. Use 1 to avoid Helm lock conflicts.";
    };

    # Legacy options (when usePackage = false)
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
            '';
          };

          dependsOn = mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              List of releases this depends on in "namespace/release-name" format.
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
            description = "Wait for resources to be ready";
          };

          timeout = mkOption {
            type = types.int;
            default = 300;
            description = "Timeout in seconds";
          };

          atomic = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Override helmDefaults.atomic";
          };

          force = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Override helmDefaults.force";
          };

          recreatePods = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Override helmDefaults.recreatePods";
          };

          valuesContent = mkOption {
            type = types.nullOr types.attrs;
            default = null;
            description = "Values as Nix attrset";
          };

          values = mkOption {
            type = types.nullOr (types.listOf types.attrs);
            default = null;
            description = "List of value sets";
          };

          setValues = mkOption {
            type = types.attrs;
            default = {};
            description = "Key-value pairs to set via --set";
          };

          set = mkOption {
            type = types.nullOr (types.listOf types.attrs);
            default = null;
            description = "List of set values";
          };

          hooks = mkOption {
            type = types.listOf types.attrs;
            default = [];
            description = "Helmfile hooks";
          };
        };
      }));
      default = [];
      description = "List of Helm releases (legacy, when usePackage=false)";
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
      default = [];
      description = "Helm chart repositories (legacy, when usePackage=false)";
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
      after =
        ["network-online.target" "k3s.service"]
        ++ optional (config.fmf.services.k3s.helmfile.layers."20-secrets".enable or false) "vault-k8s-init.service";
      wants = ["network-online.target"];
      requires =
        ["k3s.service"]
        ++ optional (config.fmf.services.k3s.helmfile.layers."20-secrets".enable or false) "vault-k8s-init.service";

      path = with pkgs; [
        kubernetes-helm
        kubectl
        git
        gnutar
        gzip
        bash
        coreutils
        vault-bin
        gnugrep
        gnused
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
