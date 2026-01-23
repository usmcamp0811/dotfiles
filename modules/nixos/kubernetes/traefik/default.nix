# path: (wherever this module lives in your flake)
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.modules.traefik;

  # Helper: build manifests for one Traefik "instance"
  mkInstanceManifests = name: inst: let
    ns = inst.namespace;

    # Make routers (if any) always use the cloudflare certResolver
    dynamicRouters =
      if inst.dynamicConfigOptions ? http && inst.dynamicConfigOptions.http ? routers
      then
        lib.mapAttrs (
          _: val:
            lib.recursiveUpdate val {
              tls.certResolver = "cloudflare";
            }
        )
        inst.dynamicConfigOptions.http.routers
      else {};

    dynamicHttp =
      # Preserve other http keys besides routers (middlewares/services/etc), but override routers.
      if inst.dynamicConfigOptions ? http
      then (lib.removeAttrs inst.dynamicConfigOptions.http ["routers"]) // {routers = dynamicRouters;}
      else {routers = dynamicRouters;};

    # Allow per-instance additional static config to layer in.
    staticYaml = lib.generators.toYAML {} (
      lib.recursiveUpdate
      (lib.recursiveUpdate config.services.traefik.staticConfigOptions {
        providers.kubernetesCRD = {};
        providers.kubernetesIngress = {
          ingressClass = inst.ingressClass;
          publishedService = {
            enabled = true;
            pathOverride = inst.publishedServicePathOverride;
          };
        };
        tls.certResolver = "cloudflare";
      })
      inst.staticConfigOptionsExtra
    );
  in {
    # Namespace with label so ClusterExternalSecret targets it
    "${name}-traefik-namespace-label".content = {
      apiVersion = "v1";
      kind = "Namespace";
      metadata = {
        name = ns;
        labels = {
          cloudflare-access = "true";
        };
      };
    };

    # Vault auth SA in this namespace
    "${name}-traefik-vault-auth-sa".content = {
      apiVersion = "v1";
      kind = "ServiceAccount";
      metadata = {
        name = "vault-auth";
        namespace = ns;
      };
      automountServiceAccountToken = true;
    };

    # ClusterRoleBinding must be unique per instance (name collision otherwise)
    "${name}-traefik-vault-auth-rbac".content = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata.name = "vault-auth-reviewer-${name}";
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "system:auth-delegator";
      };
      subjects = [
        {
          kind = "ServiceAccount";
          name = "vault-auth";
          namespace = ns;
        }
      ];
    };

    # Static config (per instance)
    "${name}-traefik-static-config".content = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "${name}-traefik-static-config";
        namespace = ns;
      };
      data."static.yaml" = staticYaml;
    };

    # Dynamic config (per instance)
    "${name}-traefik-dynamic-config".content = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "${name}-traefik-dynamic-config";
        namespace = ns;
      };
      data."dynamic.yaml" = lib.generators.toYAML {} {
        http = dynamicHttp;
      };
    };

    # HelmChart (per instance)
    "${name}-traefik".content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChart";
      metadata.name = "${name}-traefik";
      spec = {
        chart = "https://%{KUBERNETES_API}%/static/charts/traefik.tgz";
        targetNamespace = ns;
        createNamespace = true;
        helmVersion = "v3";

        valuesContent = lib.generators.toYAML {} {
          certificatesResolvers.cloudflare.acme = {
            email = cfg.cloudflare.email;
            storage = "/var/lib/traefik/acme.json";
            dnsChallenge = {
              provider = "cloudflare";
              resolvers = ["1.1.1.1:53" "1.0.0.1:53"];
            };
          };

          experimental.plugins.cloudflarewarp = {
            moduleName = "github.com/BilikoX/cloudflarewarp";
            version = "v1.3.4";
          };

          persistence = {
            enabled = false;
            name = "traefik-acme";
            accessMode = "ReadWriteOnce";
            size = "1Gi";
            path = "/var/lib/traefik";
            storageClass = "glusterfs";
          };

          env = [
            {
              name = "CLOUDFLARE_DNS_API_TOKEN";
              valueFrom.secretKeyRef = {
                name = "cloudflare-api-token-secret";
                key = "api-token";
              };
            }
          ];

          api = {
            dashboard = true;
            insecure = true;
          };

          affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector.matchExpressions = [
                {
                  key = "app.kubernetes.io/name";
                  operator = "In";
                  values = ["traefik"];
                }
              ];
              topologyKey = "kubernetes.io/hostname";
            }
          ];

          deployment = {
            namespace = ns;
            replicas = inst.replicas;
            updateStrategy = {
              type = "RollingUpdate";
              rollingUpdate = {
                maxUnavailable = 0;
                maxSurge = 1;
              };
            };
          };

          additionalArguments = [
            "--api.insecure=true"
            "--providers.kubernetescrd"
            "--providers.kubernetesingress"
            "--providers.file.filename=/dynamic/dynamic.yaml"
            "--configFile=/static/traefik.yaml"
            "--providers.file.watch=true"
          ];

          volumes = [
            {
              name = "${name}-traefik-dynamic-config";
              mountPath = "/dynamic";
              type = "configMap";
              nameOverride = "${name}-traefik-dynamic-config";
            }
            {
              name = "${name}-traefik-static-config";
              mountPath = "/static";
              type = "configMap";
              nameOverride = "${name}-traefik-static-config";
            }
          ];
        };
      };
    };
  };

  # One shared ClusterExternalSecret that fans out to any namespace with label cloudflare-access=true
  sharedManifests = {
    cloudflare-api-secret-traefik.content = {
      apiVersion = "external-secrets.io/v1beta1";
      kind = "ClusterExternalSecret";
      metadata.name = "cloudflare-api-token-secret";
      spec = {
        namespaceSelector.matchLabels = {"cloudflare-access" = "true";};
        externalSecretSpec = {
          refreshInterval = "1h";
          secretStoreRef = {
            name = "vault-backend";
            kind = "ClusterSecretStore";
          };
          target = {
            name = "cloudflare-api-token-secret";
            creationPolicy = "Owner";
          };
          data = [
            {
              secretKey = "api-token";
              remoteRef = {
                key = cfg.cloudflare.vaultKey;
                property = cfg.cloudflare.vaultProperty;
              };
            }
          ];
        };
      };
    };
  };
in {
  options.fmf.services.k3s.modules.traefik = {
    enable = mkEnableOption "Enable Traefik and supporting manifests.";

    cloudflare = {
      vaultKey = mkOption {
        type = types.str;
        default = "secret/campground/cloudflare";
        description = "Vault KV key holding the Cloudflare token.";
      };
      vaultProperty = mkOption {
        type = types.str;
        default = "CLOUDFLARE_API_KEY";
        description = "Vault KV property name for the Cloudflare token.";
      };
      email = mkOption {
        type = types.str;
        default = "cloudflare@aicampground.com";
        description = "ACME email address for Cloudflare DNS challenge.";
      };
    };

    # Multiple instances keyed by name (public/lan/etc).
    instances = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          namespace = mkOption {
            type = types.str;
            default = "${name}-traefik";
            description = "Namespace to deploy this Traefik instance into.";
          };

          replicas = mkOption {
            type = types.int;
            default = 2;
            description = "Replica count for this Traefik instance.";
          };

          ingressClass = mkOption {
            type = types.str;
            default = "traefik-${name}";
            description = "IngressClass name used by this Traefik instance.";
          };

          publishedServicePathOverride = mkOption {
            type = types.str;
            default = "kube-system/${name}-traefik";
            description = "providers.kubernetesIngress.publishedService.pathOverride";
          };

          # Raw Traefik dynamic config YAML structure (attrs) for this instance.
          # If you already have something like config.fmf.suites.public-hosting.dynamicConfigOptions,
          # just point to it per instance.
          dynamicConfigOptions = mkOption {
            type = types.attrs;
            default = {};
            description = "Traefik dynamic config options (http.{routers,services,middlewares,...}).";
          };

          # Extra bits to merge into the static config YAML for this instance.
          staticConfigOptionsExtra = mkOption {
            type = types.attrs;
            default = {};
            description = "Extra static.yaml options merged on top of config.services.traefik.staticConfigOptions.";
          };
        };
      }));

      # Default keeps your current behavior (a single 'public' instance).
      default = {
        public = {
          namespace = "public-traefik";
          ingressClass = "traefik";
          publishedServicePathOverride = "kube-system/public-traefik";
          dynamicConfigOptions = config.fmf.suites.public-hosting.dynamicConfigOptions;
        };
      };

      description = ''
        Map of Traefik instances to deploy. Example keys: public, lan.
        Each key creates its own Namespace, ConfigMaps, and HelmChart.
        All instances share the same Cloudflare token secret (ClusterExternalSecret fanout).
      '';
    };
  };

  config = mkIf cfg.enable {
    # Enable external-secrets to provide the vault-backend ClusterSecretStore
    fmf.services.k3s.modules.external-secrets.enable = true;
    fmf.services.k3s.modules.certificates.enable = true;

    services.k3s = {
      charts.traefik =
        pkgs.runCommand "traefik.tgz"
        {
          nativeBuildInputs = [pkgs.gnutar pkgs.gzip];
        } ''
          cp -r ${pkgs.nixhelmCharts.traefik.traefik} traefik
          tar -czf $out -C traefik .
        '';

      manifests = lib.mkMerge (
        [
          sharedManifests
        ]
        ++ (lib.mapAttrsToList mkInstanceManifests cfg.instances)
      );
    };
  };
}
