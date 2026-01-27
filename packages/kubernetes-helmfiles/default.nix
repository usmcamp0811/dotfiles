{
  lib,
  pkgs,
  ...
}: let
  # Use pkgs.formats.yaml for proper YAML generation
  yamlFormat = pkgs.formats.yaml {};

  # Import configuration
  defaults = import ./defaults.nix;
  repositoriesList = import ./repositories.nix;

  # Import layer functions
  mkCrdsReleases = import ./layers/00-crds.nix;
  mkControllersReleases = import ./layers/10-controllers.nix;
  mkSecretsReleases = import ./layers/20-secrets.nix {inherit defaults;};
  mkNetworkingReleases = import ./layers/30-networking.nix {inherit lib defaults;};
  mkGitopsReleases = import ./layers/60-gitops.nix {inherit lib defaults;};

  # Generate default releases with default config
  crdsReleases = mkCrdsReleases {};
  controllersReleases = mkControllersReleases {};
  defaultSecretsReleases = mkSecretsReleases {};
  defaultNetworkingReleases = mkNetworkingReleases {};
  defaultGitopsReleases = mkGitopsReleases {};

  # Helper to add createNamespace to all releases (matches helmfile module behavior)
  addCreateNamespace = release: release // {createNamespace = true;};

  # Create YAML files for individual layers
  crdsLayer = yamlFormat.generate "00-crds.yaml" {
    releases = map addCreateNamespace crdsReleases;
  };

  controllersLayer = yamlFormat.generate "10-controllers.yaml" {
    releases = map addCreateNamespace controllersReleases;
  };

  defaultSecretsLayer = yamlFormat.generate "20-secrets.yaml" {
    releases = map addCreateNamespace defaultSecretsReleases;
  };

  defaultNetworkingLayer = yamlFormat.generate "30-networking.yaml" {
    releases = map addCreateNamespace defaultNetworkingReleases;
  };

  defaultGitopsLayer = yamlFormat.generate "60-gitops.yaml" {
    releases = map addCreateNamespace defaultGitopsReleases;
  };

  repositoriesFile = yamlFormat.generate "repositories.yaml" {
    repositories = repositoriesList;
  };

  # Merge all layers into a baseline helmfile
  mkBaseline = {
    vaultAddress ? defaults.vaultAddress,
    vaultKvPath ? defaults.vaultKvPath,
    vaultKvVersion ? defaults.vaultKvVersion,
    metallb ? defaults.metallb,
    argocdIngressEnabled ? defaults.argocd.ingressEnabled,
    argocdIngressHost ? defaults.argocd.ingressHost,
    argocdIngressClass ? defaults.argocd.ingressClass,
  }: let
    secretsReleases = mkSecretsReleases {inherit vaultAddress vaultKvPath vaultKvVersion;};
    networkingReleases = mkNetworkingReleases {inherit metallb;};
    gitopsReleases = mkGitopsReleases {inherit argocdIngressEnabled argocdIngressHost argocdIngressClass;};

    # Merge all releases in layer order and add createNamespace
    allReleases = map addCreateNamespace (
      crdsReleases
      ++ controllersReleases
      ++ secretsReleases
      ++ networkingReleases
      ++ gitopsReleases
    );
  in
    yamlFormat.generate "helmfile.yaml" {
      repositories = repositoriesList;

      helmDefaults = {
        wait = true;
        timeout = 300;
        recreatePods = false;
        force = false;
        atomic = true;
      };

      releases = allReleases;
    };

  # Default baseline
  defaultBaseline = mkBaseline {};
in
  pkgs.stdenv.mkDerivation {
    name = "kubernetes-helmfiles";
    version = "1.0.0";

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/layers
      cp ${crdsLayer} $out/layers/00-crds.yaml
      cp ${controllersLayer} $out/layers/10-controllers.yaml
      cp ${defaultSecretsLayer} $out/layers/20-secrets.yaml
      cp ${defaultNetworkingLayer} $out/layers/30-networking.yaml
      cp ${defaultGitopsLayer} $out/layers/60-gitops.yaml
      cp ${repositoriesFile} $out/repositories.yaml
      cp ${defaultBaseline} $out/helmfile.yaml
    '';

    passthru = {
      # Individual layers (YAML files)
      layers = {
        crds = crdsLayer;
        controllers = controllersLayer;
        secrets = defaultSecretsLayer;
        networking = defaultNetworkingLayer;
        gitops = defaultGitopsLayer;
      };

      # Raw release data (Nix values, before YAML conversion)
      releases = {
        crds = crdsReleases;
        controllers = controllersReleases;
        secrets = defaultSecretsReleases;
        networking = defaultNetworkingReleases;
        gitops = defaultGitopsReleases;
      };

      # Functions to create custom layers/releases
      inherit mkSecretsReleases mkNetworkingReleases mkGitopsReleases;

      # Function to create custom baseline
      inherit mkBaseline;

      # Repositories
      repositories = repositoriesFile;
      inherit repositoriesList;

      # Default baseline
      baseline = defaultBaseline;

      # Defaults for reference
      inherit defaults;

      # Convenience: YAML outputs
      yaml = {
        crds = crdsLayer;
        controllers = controllersLayer;
        secrets = defaultSecretsLayer;
        networking = defaultNetworkingLayer;
        gitops = defaultGitopsLayer;
        repositories = repositoriesFile;
        baseline = defaultBaseline;
      };
    };

    meta = with lib; {
      description = "Kubernetes helmfile configurations for campground cluster";
      maintainers = [];
    };
  }
