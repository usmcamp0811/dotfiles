# Helmfile-Based Kubernetes Infrastructure

This module provides a declarative, race-condition-free way to deploy Kubernetes infrastructure using Helmfile.

## Why Helmfile?

Your previous approach using k3s HelmChart manifests and systemd workarounds had timing issues. Helmfile solves this by:

- **Explicit dependency ordering** via `dependsOn` lists
- **Wait conditions** that ensure resources are ready before proceeding
- **Layer-based deployment** for logical grouping
- **Industry standard** tooling with broad ecosystem support

## Quick Start: Baseline Infrastructure

The easiest way to get started is using the baseline infrastructure module:

```nix
{
  fmf.services.k3s.helmfile.baseline = {
    enable = true;

    # Layer 1: MetalLB
    metallb = {
      enable = true;
      ipAddressPool.addresses = ["10.8.40.100-10.8.40.255"];
    };

    # Layer 2: External Secrets
    externalSecrets.enable = true;

    # Layer 3: Vault Integration
    vault = {
      address = "http://10.8.0.3:8200";
      kvPath = "secret/campground/k3s";
      createClusterSecretStore = true;
    };

    # Layer 4: Istio Service Mesh
    istio = {
      enable = true;
      version = "1.24.2";
      ingressGateway = {
        enable = true;
        loadBalancerIP = "10.8.40.101";
      };
    };

    # Layer 5: ArgoCD
    argocd = {
      enable = true;
      ingress = {
        enable = true;
        host = "argocd.k8s.example.com";
      };
    };
  };
}
```

This will deploy all infrastructure in the correct order with proper wait conditions.

## Architecture: Deployment Layers

```
Layer 1: Infrastructure
  └─ MetalLB (LoadBalancer provider)
      ↓
Layer 2: Operators with CRDs
  └─ External Secrets Operator
      ↓
Layer 3: Stores and Secrets
  └─ ClusterSecretStore (Vault backend)
  └─ ExternalSecret objects
      ↓
Layer 4: Ingress/Service Mesh
  ├─ Istio Base (CRDs)
  ├─ Istiod (control plane)
  ├─ Istio Gateways
  └─ Traefik
      ↓
Layer 5: GitOps Platform
  └─ ArgoCD
      ↓
Layer 6+: Applications
  └─ Managed by ArgoCD App-of-Apps
```

## Advanced Usage: Custom Releases

You can add custom releases to the helmfile configuration:

```nix
{
  fmf.services.k3s.helmfile = {
    enable = true;

    releases = [
      # Layer 3: Cert-Manager
      {
        name = "cert-manager";
        namespace = "cert-manager";
        chart = "jetstack/cert-manager";
        layer = 3;
        dependsOn = ["metallb-system/metallb"];
        wait = true;
        setValues = {
          installCRDs = "true";
        };
      }

      # Layer 4: Traefik
      {
        name = "traefik";
        namespace = "public-traefik";
        chart = "traefik/traefik";
        layer = 4;
        dependsOn = [
          "cert-manager/cert-manager"
          "external-secrets/external-secrets"
        ];
        wait = true;
        valuesContent = {
          ports = {
            web = {
              port = 80;
              expose = true;
            };
            websecure = {
              port = 443;
              expose = true;
              tls.enabled = true;
            };
          };
          service = {
            type = "LoadBalancer";
          };
        };
      }

      # Layer 5: Custom application
      {
        name = "my-app";
        namespace = "default";
        chart = "./charts/my-app";
        layer = 5;
        dependsOn = ["public-traefik/traefik"];
        wait = true;
        valuesContent = {
          replicas = 3;
          image = {
            repository = "myapp";
            tag = "v1.0.0";
          };
        };
      }
    ];
  };
}
```

## Configuration Reference

### Release Options

Each release in `fmf.services.k3s.helmfile.releases` supports:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` | string | required | Release name |
| `namespace` | string | required | Kubernetes namespace |
| `chart` | string | required | Chart reference (repo/chart or ./path) |
| `layer` | int | 999 | Deployment order (lower = earlier) |
| `dependsOn` | list of strings | [] | Dependencies in "namespace/release" format |
| `createNamespace` | bool | true | Create namespace if missing |
| `wait` | bool | true | Wait for resources to be ready |
| `timeout` | int | 300 | Timeout in seconds |
| `valuesContent` | attrs | null | Values as Nix attrset |
| `setValues` | attrs | {} | Key-value pairs for `--set` |
| `hooks` | list | [] | Helmfile hooks |

### Dependency Ordering

Dependencies are specified as `"namespace/release-name"`:

```nix
{
  dependsOn = [
    "metallb-system/metallb"          # Depends on MetalLB
    "external-secrets/external-secrets" # AND External Secrets
  ];
}
```

Helmfile will:
1. Wait for all dependencies to complete successfully
2. Only then deploy this release
3. Wait for this release to be ready before dependent releases

### Layer Numbers

Recommended layer numbers:

- **1**: Core infrastructure (MetalLB, storage)
- **2**: Operators with CRDs (External Secrets, Cert-Manager)
- **3**: Configuration resources (ClusterSecretStore, ClusterIssuer)
- **4**: Ingress and service mesh (Traefik, Istio)
- **5**: GitOps platform (ArgoCD, Flux)
- **6+**: Applications (managed by ArgoCD)

Releases in the same layer may deploy concurrently (unless constrained by `dependsOn`).

## Deployment Flow

When you run `nixos-rebuild switch`:

1. **Helmfile configuration is generated** from your Nix config → `/etc/helmfile/helmfile.yaml`
2. **SystemD service starts** after k3s is ready
3. **Helmfile applies releases** in dependency order:
   - Waits for k3s API to be healthy
   - Adds Helm repositories
   - Deploys Layer 1 releases
   - Waits for Layer 1 to be ready
   - Deploys Layer 2 releases
   - ... and so on

## Debugging

### View Generated Helmfile Config

```bash
cat /etc/helmfile/helmfile.yaml
```

### Check Helmfile Service Status

```bash
systemctl status helmfile-apply
journalctl -u helmfile-apply -f
```

### Manually Run Helmfile

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
cd /etc/helmfile
helmfile list              # List all releases
helmfile status           # Show status of releases
helmfile apply            # Apply changes
helmfile diff             # Show what would change
```

### Common Issues

**Issue**: CRD not ready errors

**Solution**: The baseline module includes hooks that wait for CRDs to be established. Make sure you're using proper `dependsOn` to wait for operators before deploying resources.

**Issue**: Release stuck in pending state

**Solution**: Check the release logs:
```bash
kubectl get pods -A | grep -v Running
kubectl describe pod <pod-name> -n <namespace>
```

## Migration from k3s HelmChart Manifests

If you're currently using `services.k3s.charts.*` and `services.k3s.manifests.*`:

### Before (Old Way - Has Race Conditions)
```nix
{
  services.k3s.charts.external-secrets = ...;
  services.k3s.manifests.external-secrets.content = { ... };

  # Needed systemd workarounds for timing
  systemd.services.external-secrets-deploy = { ... };
}
```

### After (New Way - No Race Conditions)
```nix
{
  fmf.services.k3s.helmfile.baseline = {
    enable = true;
    externalSecrets.enable = true;
    # No systemd workarounds needed!
  };
}
```

## Integration with ArgoCD

Once your baseline infrastructure is deployed via Helmfile, use ArgoCD for application management:

1. **Deploy baseline via Helmfile** (Layers 1-5)
2. **Create App-of-Apps in ArgoCD** for applications (Layer 6+)
3. **Applications auto-sync** from Git

Example ArgoCD App-of-Apps:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourorg/k8s-apps
    path: apps/
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal = true
```

## Real-World Example

See `systems/x86_64-linux/vm-k8s-control-0/default.nix` for a complete working example.

Key points:
- Baseline infrastructure deployed via Helmfile
- External Secrets configured for Vault
- Traefik configured with Cloudflare integration
- Istio service mesh enabled
- ArgoCD for application management

## Benefits Over Previous Approach

| Previous Approach | Helmfile Approach |
|-------------------|-------------------|
| k3s HelmChart manifests | Helmfile with dependency ordering |
| Race conditions with CRDs | Automatic wait conditions |
| SystemD workarounds | Built-in dependency management |
| Manual ordering via systemd.after | Declarative `dependsOn` |
| Hard to debug timing issues | Clear dependency graph |
| NixOS-specific | Industry standard tool |

## Next Steps

1. **Enable baseline infrastructure** in your config
2. **Verify deployment** with `systemctl status helmfile-apply`
3. **Add custom releases** as needed
4. **Set up ArgoCD** for application management
5. **Remove old k3s HelmChart manifests** and systemd workarounds

For questions or issues, see the generated helmfile config at `/etc/helmfile/helmfile.yaml.debug`.
