# GitOps Implementation Summary

This document summarizes the GitOps baseline implementation for the Campground k3s cluster.

## What Was Implemented

### 1. Nix Package (`packages/gitops/default.nix`)

A proper Nix package with dual outputs:

**Output A: Root Application YAML**
- Located at `$out/root-app.yaml`
- Generated from parameterized function `mkRootApp`
- Points ArgoCD to `packages/gitops/clusters/campground`
- Configurable via parameters: `repoURL`, `targetRevision`, `clusterName`

**Output B: Full GitOps Tree**
- Contains entire `packages/gitops` directory structure
- Includes all clusters, apps, bootstrap documentation
- Available at `$out/` for validation and export

**Build Command:**
```bash
nix build .#gitops
# Result includes both outputs
```

### 2. GitOps Repository Structure

```
packages/gitops/
├── default.nix              # Nix package definition
├── README.md               # Main documentation
├── DEPLOYMENT.md           # Deployment guide
├── IMPLEMENTATION.md       # This file
├── bootstrap/
│   ├── root-app.yaml       # Template root Application
│   └── NOTES.md            # Bootstrap mechanism docs
├── clusters/
│   └── campground/
│       ├── kustomization.yaml
│       ├── projects/
│       │   └── platform-project.yaml
│       └── apps/
│           ├── argocd-self.yaml       # ArgoCD self-management
│           ├── storage.yaml            # GlusterFS StorageClass
│           ├── external-secrets.yaml   # External Secrets Operator
│           ├── vault-backend.yaml      # Vault ClusterSecretStore
│           ├── metallb.yaml            # MetalLB LoadBalancer
│           └── traefik.yaml            # Traefik Ingress + ACME
└── apps/
    ├── argocd/
    │   └── values.yaml                 # ArgoCD Helm values
    ├── storage/
    │   ├── README.md                   # TODO: Implement CSI driver
    │   ├── endpoints.yaml              # GlusterFS endpoints
    │   └── storageclass.yaml           # Default StorageClass
    ├── external-secrets/
    │   ├── vault-auth-serviceaccount.yaml
    │   ├── clustersecretstore.yaml
    │   └── externalsecret-cloudflare-token.yaml
    ├── metallb/
    │   ├── ippool.yaml                 # IP range 10.8.40.100-255
    │   └── l2advertisement.yaml        # L2 mode on enp0s6
    └── traefik/
        ├── values.yaml                 # Traefik Helm values
        └── ingressroutes/
            └── argocd-server.yaml      # ArgoCD UI IngressRoute
```

### 3. k3s Module Extensions (`modules/nixos/services/k3s/default.nix`)

Added GitOps bootstrap capability to the k3s module:

**New Options:**
```nix
fmf.services.k3s.gitops = {
  enable = true;
  package = pkgs.fmf.gitops;
  argocdVersion = "7.7.0";
  argocdNamespace = "argocd";
  repoURL = "https://github.com/usmcamp0811/dotfiles.git";
  targetRevision = "nixos";
  clusterName = "campground";
};
```

**Automatic Manifest Injection:**

When `gitops.enable = true`, the module automatically adds to `services.k3s.manifests`:

1. **00-argocd-install.yaml** - ArgoCD HelmChart CRD
   - Uses k3s built-in Helm controller
   - Pins ArgoCD chart version
   - Configures basic settings (insecure server for Traefik TLS termination)

2. **20-root-app.yaml** - Root Application
   - Generated from gitops package `mkRootApp` function
   - Points to `packages/gitops/clusters/campground`
   - Auto-sync with prune and selfHeal enabled

### 4. Vault Agent Bootstrap Secrets

Extended Vault Agent configuration in k3s module to render bootstrap secrets when GitOps is enabled:

**New Secret: `10-argocd-repo-secret.yaml`**

Rendered to: `/var/lib/rancher/k3s/server/manifests/10-argocd-repo-secret.yaml`

Template reads from Vault path: `secret/campground/argocd/repo`

Required Vault fields:
- `url` - Git repository URL
- `ssh_private_key` - SSH private key for repo access

Rendered as Kubernetes Secret with label `argocd.argoproj.io/secret-type: repository`

### 5. Baseline Applications

All applications use pinned chart versions and declarative configuration:

#### ArgoCD Self-Management
- **Chart:** `argo-cd` v7.7.0 from argoproj.github.io
- **Multi-source:** Chart from Helm repo, values from Git
- **Values:** `apps/argocd/values.yaml`
- **Sync Wave:** 0 (infrastructure)

#### Storage
- **Type:** GlusterFS with manual provisioning
- **Endpoints:** 10.8.0.176, 10.8.0.189
- **StorageClass:** `glusterfs` (annotated as default)
- **TODO:** Migrate to CSI driver (Kadalu or glusterfs-csi-driver)
- **Sync Wave:** 0 (infrastructure)

#### External Secrets
- **Chart:** `external-secrets` v0.12.1 from charts.external-secrets.io
- **CRDs:** Installed with chart
- **Sync Wave:** 1 (dependencies for other apps)

#### Vault Backend
- **Components:**
  - ServiceAccount `vault-auth` in `external-secrets` namespace
  - ClusterSecretStore `vault-backend` pointing to Vault at 10.8.0.3:8200
  - ExternalSecret for Cloudflare API token (consumed by Traefik)
- **Vault Auth:** Kubernetes auth via ServiceAccount
- **Sync Wave:** 1 (dependencies for other apps)

#### MetalLB
- **Chart:** `metallb` v0.14.9 from metallb.github.io
- **Multi-source:** Chart from Helm repo, manifests from Git
- **IP Pool:** 10.8.40.100 - 10.8.40.255
- **Mode:** L2 on interface `enp0s6`
- **Sync Wave:** 2 (networking infrastructure)

#### Traefik
- **Chart:** `traefik` v32.2.0 from traefik.github.io
- **Multi-source:** Chart from Helm repo, values and IngressRoutes from Git
- **LoadBalancer:** Uses MetalLB
- **ACME:** Cloudflare DNS-01 challenge
- **Certificate Email:** k8s-admin@aicampground.com
- **Persistence:** 128Mi PVC for acme.json
- **IngressRoute:** ArgoCD UI at argocd.k8s.aicampground.com
- **Sync Wave:** 3 (depends on MetalLB and External Secrets)

### 6. Bootstrap Sequence

```
Node Boot
  ↓
1. Vault Agent authenticates (AppRole)
  ↓
2. Vault Agent renders:
   - k3s-token (for cluster join)
   - 10-argocd-repo-secret.yaml (Git credentials)
  ↓
3. k3s starts
  ↓
4. k3s applies manifests from /var/lib/rancher/k3s/server/manifests/:
   - 00-argocd-install.yaml → ArgoCD Helm install
   - 10-argocd-repo-secret.yaml → Repo credentials
   - 20-root-app.yaml → Root Application
  ↓
5. ArgoCD pods start
  ↓
6. ArgoCD Application controller processes root app
  ↓
7. ArgoCD syncs child applications in waves:
   Wave 0: argocd-self, storage
   Wave 1: external-secrets, vault-backend
   Wave 2: metallb
   Wave 3: traefik
  ↓
8. Steady state - GitOps active
```

## What Was NOT Implemented

### Storage CSI Driver

Current implementation uses deprecated in-tree GlusterFS plugin with manual provisioning.

**Required for production:**
- Implement Kadalu CSI driver (recommended)
  - Chart: https://kadalu.io/docs/k8s-storage/latest/
  - Simpler than official GlusterFS CSI
- Or implement official GlusterFS CSI driver
  - Repo: https://github.com/gluster/glusterfs-csi-driver

**Migration path documented in:** `packages/gitops/apps/storage/README.md`

### ArgoCD SSO/RBAC

Current implementation uses basic admin user with insecure server mode.

**For production, add:**
- OIDC/SAML integration (Authentik, Keycloak, etc.)
- RBAC policies for team access
- SSO secret via External Secrets

### Multi-Cluster Support

Current implementation is single-cluster (`campground`).

**To add more clusters:**
1. Create `packages/gitops/clusters/<cluster-name>/`
2. Deploy with `clusterName = "<cluster-name>"`
3. Optionally use same base apps, different values per cluster

### Cluster Autoscaler / Node Provisioning

Static node pool - no autoscaling implemented.

### Observability Stack

No monitoring/logging baseline included.

**Common additions:**
- Prometheus + Grafana
- Loki for logs
- Alertmanager
- ServiceMonitors for ArgoCD, Traefik, etc.

## Key Design Decisions

### 1. k3s HelmChart CRD vs. Direct Manifests

**Chose:** k3s HelmChart CRD for ArgoCD install

**Why:**
- Leverages k3s built-in Helm controller
- No external helmfile/helm CLI needed at bootstrap
- k3s handles chart download and lifecycle
- Consistent with k3s patterns

**Alternative:** Direct YAML manifests
- Would require pre-rendering ArgoCD install YAML
- More brittle (version changes require YAML regeneration)

### 2. Multi-Source Applications vs. Values in ConfigMaps

**Chose:** Multi-source Applications (chart + values from Git)

**Why:**
- Values are version-controlled in Git
- Changes to values trigger ArgoCD sync
- No external ConfigMap management
- ArgoCD 2.6+ native feature

**Alternative:** Helm chart with values in ConfigMap
- Requires separate ConfigMap management
- Values not in Git

### 3. Bootstrap Secrets via Vault Agent vs. External Secrets

**Chose:** Vault Agent for bootstrap secrets, External Secrets for runtime

**Why:**
- ArgoCD needs repo credentials BEFORE External Secrets is running
- Circular dependency: External Secrets → ArgoCD → External Secrets
- Vault Agent runs as systemd service before k3s

**Bootstrap secrets:**
- ArgoCD Git repo credentials

**Runtime secrets:**
- Cloudflare API token
- Application secrets

### 4. Sync Waves vs. Dependencies

**Chose:** Sync waves for ordering

**Why:**
- Explicit ordering (0, 1, 2, 3)
- No complex dependency graphs
- Clear understanding of bootstrap order

**Waves:**
- 0: Infrastructure (ArgoCD, Storage)
- 1: Secret management (External Secrets, Vault)
- 2: Networking (MetalLB)
- 3: Ingress (Traefik)

### 5. Nix Package vs. Shell Scripts

**Chose:** Nix package for GitOps content

**Why:**
- Declarative root app generation
- Type-safe parameters
- Build-time validation
- Consistent with NixOS ecosystem
- Reproducible builds

**Alternative:** Shell scripts to template YAML
- More fragile
- No build-time validation

## Testing the Implementation

### Build Validation

```bash
# Test Nix package builds
nix build .#gitops

# Verify outputs
ls -la result/
cat result/root-app.yaml

# Test custom parameters
nix eval --json '.#gitops.passthru' --apply 'p: p.mkRootApp { repoURL = "https://example.com/repo.git"; }'
```

### Syntax Validation

```bash
# Validate YAML syntax
find packages/gitops -name "*.yaml" -exec yamllint {} \;

# Validate Kubernetes manifests
find packages/gitops/apps -name "*.yaml" -exec kubectl apply --dry-run=client -f {} \;

# Validate with kubeconform
kubeconform -summary packages/gitops/apps/**/*.yaml
```

### Integration Testing

1. Deploy to test k3s cluster
2. Verify bootstrap sequence in logs
3. Check all applications reach Healthy status
4. Test each component (create PVC, MetalLB IP, Traefik cert, etc.)

## Future Enhancements

1. **Replace storage with CSI driver** (high priority)
2. **Add observability stack** (Prometheus, Grafana, Loki)
3. **Implement ArgoCD SSO** with Authentik/Keycloak
4. **Add ApplicationSet** for app-of-apps pattern
5. **Implement progressive delivery** (Argo Rollouts)
6. **Add policy enforcement** (OPA Gatekeeper, Kyverno)
7. **Implement backup/restore** (Velero)
8. **Add cost monitoring** (OpenCost, Kubecost)

## References

- ArgoCD docs: https://argo-cd.readthedocs.io/
- k3s docs: https://docs.k3s.io/
- External Secrets: https://external-secrets.io/
- MetalLB: https://metallb.universe.tf/
- Traefik: https://doc.traefik.io/traefik/
