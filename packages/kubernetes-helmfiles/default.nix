{
  lib,
  pkgs,
  ...
}: let
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

  # Helper to convert Nix attrset to YAML
  toYAML = value: builtins.toJSON value;

  # Layer 00: CRDs
  crdsLayer = pkgs.writeText "00-crds.yaml" (toYAML {
    releases = [
      {
        name = "external-secrets";
        namespace = "external-secrets";
        chart = "external-secrets/external-secrets";
        version = null;
        wait = true;
        timeout = 300;
      }
    ];
  });

  # Layer 10: Controllers
  controllersLayer = pkgs.writeText "10-controllers.yaml" (toYAML {
    releases = [
      {
        name = "cert-manager";
        namespace = "cert-manager";
        chart = "jetstack/cert-manager";
        version = null;
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
  });

  # Layer 20: Secrets (function to support configuration)
  mkSecretsLayer = {
    vaultAddress ? defaults.vaultAddress,
    vaultKvPath ? defaults.vaultKvPath,
    vaultKvVersion ? defaults.vaultKvVersion,
  }:
    pkgs.writeText "20-secrets.yaml" (toYAML {
      releases = [
        {
          name = "vault-auth-serviceaccount";
          namespace = "external-secrets";
          chart = "dysnix/raw";
          version = null;
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
          version = null;
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
    });

  # Layer 30: Networking (function to support MetalLB configuration)
  mkNetworkingLayer = {
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
  in
    pkgs.writeText "30-networking.yaml" (toYAML {
      releases = [
        {
          name = "metallb";
          namespace = "metallb-system";
          chart = "metallb/metallb";
          version = null;
          needs = ["external-secrets/external-secrets"];
          wait = true;
          timeout = 900;
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
    });

  # Layer 60: GitOps
  gitopsLayer = pkgs.writeText "60-gitops.yaml" (toYAML {
    releases = [
      {
        name = "argocd";
        namespace = "argocd";
        chart = "argo/argo-cd";
        version = null;
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
                type = "LoadBalancer";
                annotations = {
                  "metallb.universe.tf/address-pool" = "default-pool";
                };
              };
            };
          }
        ];
      }
    ];
  });

  # Repositories configuration
  repositories = pkgs.writeText "repositories.yaml" (toYAML {
    repositories = [
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
  });

  # Generate default layers
  defaultSecretsLayer = mkSecretsLayer {};
  defaultNetworkingLayer = mkNetworkingLayer {};

  # Merge all layers into a baseline helmfile
  mkBaseline = {
    vaultAddress ? defaults.vaultAddress,
    vaultKvPath ? defaults.vaultKvPath,
    vaultKvVersion ? defaults.vaultKvVersion,
    metallb ? defaults.metallb,
  }: let
    secretsLayer = mkSecretsLayer {inherit vaultAddress vaultKvPath vaultKvVersion;};
    networkingLayer = mkNetworkingLayer {inherit metallb;};

    # Read and parse each layer
    crdsReleases = (builtins.fromJSON (builtins.readFile crdsLayer)).releases;
    controllersReleases = (builtins.fromJSON (builtins.readFile controllersLayer)).releases;
    secretsReleases = (builtins.fromJSON (builtins.readFile secretsLayer)).releases;
    networkingReleases = (builtins.fromJSON (builtins.readFile networkingLayer)).releases;
    gitopsReleases = (builtins.fromJSON (builtins.readFile gitopsLayer)).releases;

    # Merge all releases in layer order
    allReleases =
      crdsReleases
      ++ controllersReleases
      ++ secretsReleases
      ++ networkingReleases
      ++ gitopsReleases;

    repos = (builtins.fromJSON (builtins.readFile repositories)).repositories;
  in
    pkgs.writeText "helmfile.yaml" (toYAML {
      repositories = repos;
      releases = allReleases;
    });

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
      cp ${gitopsLayer} $out/layers/60-gitops.yaml
      cp ${repositories} $out/repositories.yaml
      cp ${defaultBaseline} $out/helmfile.yaml
    '';

    passthru = {
      # Individual layers
      layers = {
        crds = crdsLayer;
        controllers = controllersLayer;
        secrets = defaultSecretsLayer;
        networking = defaultNetworkingLayer;
        gitops = gitopsLayer;
      };

      # Functions to create custom layers
      mkSecretsLayer = mkSecretsLayer;
      mkNetworkingLayer = mkNetworkingLayer;

      # Function to create custom baseline
      mkBaseline = mkBaseline;

      # Repositories
      repositories = repositories;

      # Default baseline
      baseline = defaultBaseline;

      # Convenience: YAML outputs
      yaml = {
        crds = crdsLayer;
        controllers = controllersLayer;
        secrets = defaultSecretsLayer;
        networking = defaultNetworkingLayer;
        gitops = gitopsLayer;
        repositories = repositories;
        baseline = defaultBaseline;
      };
    };

    meta = with lib; {
      description = "Kubernetes helmfile configurations for campground cluster";
      maintainers = [];
    };
  }
