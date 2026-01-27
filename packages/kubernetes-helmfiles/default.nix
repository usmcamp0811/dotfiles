{
  lib,
  pkgs,
  ...
}: let
  # Use pkgs.formats.yaml for proper YAML generation
  yamlFormat = pkgs.formats.yaml {};

  # Default configuration values
  defaults = {
    vaultAddress = "http://10.8.0.3:8200";
    vaultKvPath = "secret/campground/k3s";
    vaultKvVersion = "v2";
    metallb = {
      ipPool = {
        name = "default-pool";
        addresses = ["10.8.40.100-10.8.40.255"];
        autoAssign = true;
      };
    };
  };

  # Layer data as Nix values (not YAML yet)
  crdsReleases = [
    {
      name = "external-secrets";
      namespace = "external-secrets";
      chart = "external-secrets/external-secrets";
      wait = true;
      timeout = 300;
    }
  ];

  controllersReleases = [
    {
      name = "cert-manager";
      namespace = "cert-manager";
      chart = "jetstack/cert-manager";
      wait = true;
      timeout = 600;
      set = [
        {
          name = "installCRDs";
          value = "true";
        }
        {
          name = "startupapicheck.enabled";
          value = "false";
        }
      ];
    }
  ];

  # Layer 20: Secrets (function to support configuration)
  mkSecretsReleases = {
    vaultAddress ? defaults.vaultAddress,
    vaultKvPath ? defaults.vaultKvPath,
    vaultKvVersion ? defaults.vaultKvVersion,
  }: [
    {
      name = "vault-auth-serviceaccount";
      namespace = "external-secrets";
      chart = "dysnix/raw";
      needs = ["external-secrets/external-secrets"];
      values = [
        {
          resources = [
            {
              apiVersion = "v1";
              kind = "ServiceAccount";
              metadata = {
                name = "vault-auth";
                namespace = "external-secrets";
              };
              automountServiceAccountToken = true;
            }
          ];
        }
      ];
    }
    {
      name = "vault-cluster-secret-store";
      namespace = "kube-system";
      chart = "dysnix/raw";
      needs = [
        "external-secrets/external-secrets"
        "external-secrets/vault-auth-serviceaccount"
      ];
      hooks = [
        {
          events = ["presync"];
          showlogs = true;
          command = "kubectl";
          args = [
            "delete"
            "validatingwebhookconfiguration"
            "secretstore-validate"
            "--ignore-not-found=true"
          ];
        }
      ];
      values = [
        {
          resources = [
            {
              apiVersion = "external-secrets.io/v1";
              kind = "ClusterSecretStore";
              metadata = {
                name = "vault-backend";
              };
              spec = {
                provider = {
                  vault = {
                    server = vaultAddress;
                    path = vaultKvPath;
                    version = vaultKvVersion;
                    auth = {
                      kubernetes = {
                        mountPath = "kubernetes";
                        role = "external-secrets";
                        serviceAccountRef = {
                          name = "vault-auth";
                          namespace = "external-secrets";
                        };
                      };
                    };
                  };
                };
              };
            }
          ];
        }
      ];
    }
  ];

  # Layer 30: Networking (function to support MetalLB configuration)
  mkNetworkingReleases = {
    metallb ? defaults.metallb,
  }: let
    metallbConfigManifest = ''
      apiVersion: metallb.io/v1beta1
      kind: IPAddressPool
      metadata:
        name: ${metallb.ipPool.name}
        namespace: metallb-system
      spec:
        addresses:
        ${lib.concatMapStringsSep "\n" (addr: "  - ${addr}") metallb.ipPool.addresses}
        autoAssign: ${
        if metallb.ipPool.autoAssign
        then "true"
        else "false"
      }
      ---
      apiVersion: metallb.io/v1beta1
      kind: L2Advertisement
      metadata:
        name: ${metallb.ipPool.name}-l2
        namespace: metallb-system
      spec:
        ipAddressPools:
          - ${metallb.ipPool.name}
    '';
  in [
    {
      name = "metallb";
      namespace = "metallb-system";
      chart = "metallb/metallb";
      needs = ["external-secrets/external-secrets"];
      wait = true;
      timeout = 900;
      atomic = false;  # MetalLB can take a while
      set = [
        {
          name = "controller.webhookMode";
          value = "disabled";
        }
      ];
      hooks = [
        {
          events = ["postsync"];
          showlogs = true;
          command = "sh";
          args = [
            "-c"
            ''
              echo "Waiting for MetalLB controller to be ready..."
              kubectl wait --for=condition=available --timeout=120s deployment/metallb-controller -n metallb-system

              echo "Removing MetalLB validating webhook (workaround for Service routing issue)..."
              kubectl delete validatingwebhookconfiguration metallb-webhook-configuration --ignore-not-found=true

              echo "Applying MetalLB configuration..."
              cat <<'METALLB_EOF' | kubectl apply -f -
              ${metallbConfigManifest}
              METALLB_EOF
            ''
          ];
        }
      ];
    }
  ];

  # Layer 60: GitOps
  mkGitopsReleases = {
    argocdIngressEnabled ? false,
    argocdIngressHost ? "argocd.k8s.example.com",
    argocdIngressClass ? "traefik-k8s",
  }: [
    {
      name = "argocd";
      namespace = "argocd";
      chart = "argo/argo-cd";
      needs = [
        "external-secrets/external-secrets"
        "metallb-system/metallb"
        "cert-manager/cert-manager"
      ];
      wait = true;
      timeout = 600;
      values = [
        {
          server = {
            service = {
              type = "ClusterIP";
            };
          } // lib.optionalAttrs argocdIngressEnabled {
            ingress = {
              enabled = true;
              ingressClassName = argocdIngressClass;
              hostname = argocdIngressHost;
              annotations = {
                "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
                "traefik.ingress.kubernetes.io/router.tls" = "true";
              };
              tls = true;
            };
          };
        }
      ];
    }
  ];

  # Default gitops releases (without ingress)
  gitopsReleases = mkGitopsReleases {};

  # Repositories
  repositoriesList = [
    {
      name = "external-secrets";
      url = "https://charts.external-secrets.io";
    }
    {
      name = "jetstack";
      url = "https://charts.jetstack.io";
    }
    {
      name = "dysnix";
      url = "https://dysnix.github.io/charts";
    }
    {
      name = "metallb";
      url = "https://metallb.github.io/metallb";
    }
    {
      name = "argo";
      url = "https://argoproj.github.io/argo-helm";
    }
  ];

  # Generate default releases with default config
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
    argocdIngressEnabled ? false,
    argocdIngressHost ? "argocd.k8s.example.com",
    argocdIngressClass ? "traefik-k8s",
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
      mkSecretsReleases = mkSecretsReleases;
      mkNetworkingReleases = mkNetworkingReleases;
      mkGitopsReleases = mkGitopsReleases;

      # Function to create custom baseline
      mkBaseline = mkBaseline;

      # Repositories
      repositories = repositoriesFile;
      repositoriesList = repositoriesList;

      # Default baseline
      baseline = defaultBaseline;

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
