# Layer 30: Networking
# MetalLB load balancer with IP pool configuration and Traefik ingress controller
{
  lib,
  defaults,
}: {
  metallb ? defaults.metallb,
  traefik ? defaults.traefik,
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
  [
    {
      name = "metallb";
      namespace = "metallb-system";
      chart = "metallb/metallb";
      needs = ["external-secrets/external-secrets"];
      wait = true;
      timeout = 900;
      atomic = false; # MetalLB can take a while
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
  ]
  ++ lib.optionals traefik.enabled [
    # ExternalSecret for Cloudflare API token
    {
      name = "traefik-cloudflare-secret";
      namespace = "traefik-k8s";
      chart = "dysnix/raw";
      needs = ["external-secrets/external-secrets"];

      hooks = [
        {
          events = ["presync"];
          showlogs = true;
          command = "sh";
          args = [
            "-c"
            ''
              echo "Waiting for ExternalSecrets CRD to be discoverable..."
              until kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; do
                sleep 2
              done
              # extra: ensure discovery sees it (helps right after CRD install)
              kubectl api-resources | grep -i 'externalsecrets' || true

              echo "Removing ExternalSecret validating webhook to avoid connectivity issues..."
              kubectl delete validatingwebhookconfiguration externalsecret-validate --ignore-not-found=true

              echo "ExternalSecret webhook validation disabled. Ready to create ExternalSecret."
            ''
          ];
        }
      ];

      values = [
        {
          resources = [
            {
              apiVersion = "external-secrets.io/v1"; # keep v1
              kind = "ExternalSecret";
              metadata = {
                name = traefik.cloudflareSecretName;
                namespace = "traefik-k8s";
              };
              spec = {
                refreshInterval = "1h";
                secretStoreRef = {
                  name = "vault-backend";
                  kind = "ClusterSecretStore";
                };
                target = {
                  name = traefik.cloudflareSecretName;
                  creationPolicy = "Owner";
                };
                data = [
                  {
                    secretKey = traefik.cloudflareSecretKey;
                    remoteRef = {
                      key = "cloudflare";
                      property = "CLOUDFLARE_API_KEY";
                    };
                  }
                ];
              };
            }
          ];
        }
      ];
    }

    # Traefik ingress controller
    {
      name = "traefik";
      namespace = "traefik-k8s";
      chart = "traefik/traefik";
      needs = ["metallb-system/metallb" "traefik-k8s/traefik-cloudflare-secret"];
      wait = true;
      timeout = 300;
      values = [
        {
          service.type = "LoadBalancer";

          ports = {
            web = {
              port = 80;
              exposedPort = 80;
            };
            websecure = {
              port = 443;
              exposedPort = 443;
            };
            traefik = {
              port = 9000;
              expose.default = true;
              exposedPort = 8080;
            };
          };

          ingressClass = {
            enabled = true;
            isDefaultClass = false;
          };

          ingressRoute.dashboard.enabled = true;

          providers = {
            kubernetesCRD = {
              enabled = true;
              allowCrossNamespace = true;
            };
            kubernetesIngress = {
              enabled = true;
              allowExternalNameServices = true;
            };
          };

          additionalArguments = [
            "--certificatesresolvers.cloudflare.acme.email=${traefik.acmeEmail}"
            "--certificatesresolvers.cloudflare.acme.storage=/data/acme.json"
            "--certificatesresolvers.cloudflare.acme.dnschallenge=true"
            "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare"
            "--certificatesresolvers.cloudflare.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
          ];

          env = [
            {
              name = "CF_DNS_API_TOKEN";
              valueFrom.secretKeyRef = {
                name = traefik.cloudflareSecretName;
                key = traefik.cloudflareSecretKey;
              };
            }
          ];

          persistence = {
            enabled = true;
            accessMode = "ReadWriteOnce";
            size = "128Mi";
            path = "/data";
          };
        }
      ];
    }
  ]
