{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.kubernetes.traefik;
in
{
  options.campground.kubernetes.traefik = {
    enable = mkEnableOption "Enable Traefik and supporting manifests.";
  };

  config = mkIf cfg.enable {
    services.k3s = {
      charts.traefik =
        pkgs.runCommand "traefik.tgz"
          {
            nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
          } ''
          cp -r ${pkgs.nixhelmCharts.traefik.traefik} traefik
          tar -czf $out -C traefik .
        '';

      manifests = {
        public-traefik-namespace-label.content = {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = "public-traefik";
            labels = {
              cloudflare-access = "true";
            };
          };
        };

        pub-traefik-vault-auth-sa.content = {
          apiVersion = "v1";
          kind = "ServiceAccount";
          metadata = {
            name = "vault-auth";
            namespace = "public-traefik";
          };
          spec.automountServiceAccountToken = true;
        };

        vault-auth-rbac.content = {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRoleBinding";
          metadata.name = "vault-auth-reviewer";
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "system:auth-delegator";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "vault-auth";
              namespace = "public-traefik";
            }
          ];
        };

        cloudflare-api-secret-traefik.content = {
          apiVersion = "external-secrets.io/v1beta1";
          kind = "ClusterExternalSecret";
          metadata.name = "cloudflare-api-token-secret";
          spec = {
            namespaceSelector.matchLabels = { "cloudflare-access" = "true"; };
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
                    key = "secret/campground/cloudflare";
                    property = "CLOUDFLARE_API_KEY";
                  };
                }
              ];
            };
          };
        };

        public-traefik.content = {
          apiVersion = "helm.cattle.io/v1";
          kind = "HelmChart";
          metadata.name = "public-traefik";
          spec = {
            chart = "https://%{KUBERNETES_API}%/static/charts/traefik.tgz";
            targetNamespace = "public-traefik";
            createNamespace = true;
            helmVersion = "v3";
            valuesContent = lib.generators.toYAML { } {
              certificatesResolvers.cloudflare.acme = {
                email = "cloudflare@aicampground.com";
                storage = "/var/lib/traefik/acme.json";
                dnsChallenge = {
                  provider = "cloudflare";
                  resolvers = [ "1.1.1.1:53" "1.0.0.1:53" ];
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
                storageClass = "local-path";
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
                      values = [ "traefik" ];
                    }
                  ];
                  topologyKey = "kubernetes.io/hostname";
                }
              ];
              deployment = {
                namespace = "public-traefik";
                replicas = 2;
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
                  name = "public-traefik-dynamic-config";
                  mountPath = "/dynamic";
                  type = "configMap";
                  nameOverride = "public-traefik-dynamic-config";
                }
                {
                  name = "traefik-static-config";
                  mountPath = "/static";
                  type = "configMap";
                  nameOverride = "traefik-static-config";
                }
              ];
            };
          };
        };

        traefik-static-config.content = {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "traefik-static-config";
            namespace = "public-traefik";
          };
          data."static.yaml" = lib.generators.toYAML { } (
            lib.recursiveUpdate config.services.traefik.staticConfigOptions {
              providers.kubernetesCRD = { };
              providers.kubernetesIngress = {
                ingressClass = "traefik";
                publishedService = {
                  enabled = true;
                  pathOverride = "kube-system/public-traefik";
                };
              };
              tls.certResolver = "cloudflare";
            }
          );
        };

        public-traefik-routes.content = {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "public-traefik-dynamic-config";
            namespace = "public-traefik";
          };
          data."dynamic.yaml" = lib.generators.toYAML { } {
            http =
              {
                routers =
                  lib.mapAttrs
                    (_: val:
                      lib.recursiveUpdate val {
                        tls.certResolver = "cloudflare";
                      })
                    config.campground.suites.public-hosting.dynamicConfigOptions.http.routers;
              }
              // (lib.removeAttrs config.campground.suites.public-hosting.dynamicConfigOptions.http [ "routers" ]);
          };
        };
      };
    };
  };
}
