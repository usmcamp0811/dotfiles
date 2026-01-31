{
  lib,
  pkgs,
  ...
}: let
  yamlFormat = pkgs.formats.yaml {};

  # Configuration defaults
  defaults = {
    repoURL = "https://github.com/usmcamp0811/dotfiles.git";
    targetRevision = "nixos";
    clusterName = "campground";
  };

  # Generate root Application YAML
  mkRootApp = {
    repoURL ? defaults.repoURL,
    targetRevision ? defaults.targetRevision,
    clusterName ? defaults.clusterName,
    clusterPath ? "packages/gitops/clusters/${clusterName}",
  }: let
    rootAppContent = {
      apiVersion = "argoproj.io/v1alpha1";
      kind = "Application";
      metadata = {
        name = "root";
        namespace = "argocd";
        finalizers = [
          "resources-finalizer.argocd.argoproj.io"
        ];
      };
      spec = {
        project = "default";
        source = {
          inherit repoURL targetRevision;
          path = clusterPath;
        };
        destination = {
          server = "https://kubernetes.default.svc";
          namespace = "argocd";
        };
        syncPolicy = {
          automated = {
            prune = true;
            selfHeal = true;
            allowEmpty = false;
          };
          syncOptions = [
            "CreateNamespace=true"
            "ServerSideApply=true"
          ];
          retry = {
            limit = 5;
            backoff = {
              duration = "5s";
              factor = 2;
              maxDuration = "3m";
            };
          };
        };
      };
    };
  in
    yamlFormat.generate "root-app.yaml" rootAppContent;

  # Default root app with default configuration
  defaultRootApp = mkRootApp {};

  # Copy entire gitops tree for the full package output
  gitopsTree = pkgs.runCommand "gitops-tree" {} ''
    mkdir -p $out
    cp -r ${./bootstrap} $out/bootstrap
    cp -r ${./clusters} $out/clusters
    cp -r ${./apps} $out/apps
    cp ${./README.md} $out/README.md
  '';
in
  pkgs.stdenv.mkDerivation {
    name = "gitops";
    version = "1.0.0";

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out

      # Install root-app.yaml as the primary output
      cp ${defaultRootApp} $out/root-app.yaml

      # Install the full gitops tree
      cp -r ${gitopsTree}/* $out/
    '';

    passthru = {
      # Function to create custom root app with parameters
      inherit mkRootApp;

      # Pre-built default root app
      rootApp = defaultRootApp;

      # Full gitops tree
      tree = gitopsTree;

      # Defaults for reference
      inherit defaults;

      # Individual directories for selective use
      bootstrap = ./bootstrap;
      clusters = ./clusters;
      apps = ./apps;
    };

    meta = with lib; {
      description = "GitOps baseline for Campground k3s cluster using ArgoCD";
      maintainers = [];
    };
  }
