# GitOps Apps Directory

This directory contains **application configuration and manifests** that are referenced by ArgoCD Application CRDs.

## Purpose

The `apps/` directory is **not redundant** with `clusters/campground/apps/` - they serve different purposes:

### `clusters/campground/apps/` - Application Definitions
ArgoCD Application CRDs that declare **what to deploy**:
- Which Helm chart to use
- Where to get it (Helm repo URL)
- Sync policies (auto-sync, waves, prune)
- Which values files to use (references this `apps/` directory)

### `apps/` - Application Configuration
The actual **configuration content**:
- Helm `values.yaml` files
- Custom Kubernetes manifests
- IngressRoutes, StorageClasses, etc.

## Multi-Source Pattern

This implements ArgoCD's **multi-source pattern**:

```yaml
# clusters/campground/apps/traefik.yaml
spec:
  sources:
    # Source 1: Helm chart from upstream
    - repoURL: https://traefik.github.io/charts
      chart: traefik
      targetRevision: 32.2.0
      helm:
        valueFiles:
          - $values/apps/traefik/values.yaml  # ← References this directory

    # Source 2: Values from Git (this repo)
    - repoURL: https://github.com/usmcamp0811/dotfiles.git
      targetRevision: nixos
      ref: values
```

## Directory Structure

```
apps/
├── argocd/
│   └── values.yaml              # ArgoCD Helm chart customization
├── external-secrets/
│   ├── clustersecretstore.yaml  # Vault backend configuration
│   └── externalsecret-*.yaml    # Secret definitions
├── metallb/
│   ├── ippool.yaml              # IP address pool (10.8.40.100-255)
│   └── l2advertisement.yaml     # L2 mode configuration
├── storage/
│   ├── endpoints.yaml           # GlusterFS endpoints
│   └── storageclass.yaml        # Default StorageClass
└── traefik/
    ├── values.yaml              # Traefik Helm values
    └── ingressroutes/
        └── argocd-server.yaml   # ArgoCD UI ingress
```

## Benefits

1. **Separation of concerns**: App definitions vs app content
2. **Version control**: All configuration in Git
3. **Reusability**: Same `apps/` content can be used by multiple clusters
4. **Multi-cluster ready**: Different clusters can use different values:
   ```
   apps/traefik/values.yaml        # Default values
   apps/traefik/values-prod.yaml   # Production overrides
   ```

## Example: How It Works

When ArgoCD processes `clusters/campground/apps/metallb.yaml`:

1. Fetches MetalLB Helm chart from `https://metallb.github.io/metallb`
2. Fetches manifests from `apps/metallb/` in this repo
3. Merges chart + manifests
4. Deploys to cluster

The Application CRD is just the **pointer**, this directory contains the **content**.

## See Also

- `../clusters/campground/apps/` - Application CRDs that reference this directory
- `../IMPLEMENTATION.md` - Complete implementation details
- ArgoCD multi-source docs: https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/
