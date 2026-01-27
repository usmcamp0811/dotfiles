# Layer 30: Networking
# MetalLB load balancer with IP pool configuration
{
  lib,
  defaults,
}: {
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
