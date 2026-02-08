# ArgoCD Architecture: Bootstrap vs Self-Managed

This document describes the dual-ArgoCD architecture used in the Campground cluster.

## Overview

The cluster uses **two separate ArgoCD instances** with distinct purposes:

1. **Bootstrap ArgoCD** (`argocd-bootstrap` namespace) - Platform infrastructure management
2. **Self-Managed ArgoCD** (`argocd` namespace) - Application development workloads

This separation provides a clean boundary between infrastructure and applications, ensuring platform components are always available even during application deployment issues.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ k3s Control Plane Node                                              │
│                                                                     │
│  On Boot:                                                           │
│  1. Vault Agent renders secrets → /var/lib/rancher/k3s/server/manifests/ │
│  2. k3s auto-applies manifests in /var/lib/rancher/k3s/server/manifests/ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ argocd-bootstrap namespace                                    │ │
│  │                                                               │ │
│  │  ┌─────────────────────────────────────────┐                 │ │
│  │  │ Bootstrap ArgoCD (auto-deployed by k3s) │                 │ │
│  │  │                                         │                 │ │
│  │  │ - Deployed via k3s HelmChart CRD        │                 │ │
│  │  │ - Repo: gitlab.com/usmcamp0811/dotfiles │                 │ │
│  │  │ - Manages platform infrastructure       │                 │ │
│  │  └─────────────────────────────────────────┘                 │ │
│  │           │                                                   │ │
│  │           │ manages (via Application CRs in                  │ │
│  │           │         argocd-bootstrap namespace)               │ │
│  │           ↓                                                   │ │
│  │  ┌─────────────────────────────────────────┐                 │ │
│  │  │ Platform Application CRs:               │                 │ │
│  │  │  - root (App-of-Apps)                   │                 │ │
│  │  │  - argocd-self                          │                 │ │
│  │  │  - platform-project (AppProject)        │                 │ │
│  │  │  - external-secrets                     │                 │ │
│  │  │  - vault-backend                        │                 │ │
│  │  │  - metallb                              │                 │ │
│  │  │  - traefik                              │                 │ │
│  │  │  - longhorn                             │                 │ │
│  │  │  - istio-base                           │                 │ │
│  │  │  - istiod                               │                 │ │
│  │  │  - kiali                                │                 │ │
│  │  │  - prometheus                           │                 │ │
│  │  └─────────────────────────────────────────┘                 │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ argocd namespace                                              │ │
│  │                                                               │ │
│  │  ┌─────────────────────────────────────────┐                 │ │
│  │  │ Self-Managed ArgoCD                     │                 │ │
│  │  │                                         │                 │ │
│  │  │ - Deployed by argocd-self Application   │                 │ │
│  │  │ - Managed by Bootstrap ArgoCD           │                 │ │
│  │  │ - Can point to different repos          │                 │ │
│  │  │ - For application/dev workloads         │                 │ │
│  │  │ - Currently reads from same repo        │                 │ │
│  │  │   (gitlab.com/usmcamp0811/dotfiles)     │                 │ │
│  │  │   but can be reconfigured               │                 │ │
│  │  └─────────────────────────────────────────┘                 │ │
│  │           │                                                   │ │
│  │           │ would manage                                      │ │
│  │           ↓                                                   │ │
│  │  ┌─────────────────────────────────────────┐                 │ │
│  │  │ Application workloads:                  │                 │ │
│  │  │  - Your applications                    │                 │ │
│  │  │  - Dev services                         │                 │ │
│  │  │  - Non-platform apps                    │                 │ │
│  │  └─────────────────────────────────────────┘                 │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Bootstrap ArgoCD (`argocd-bootstrap` namespace)

### Purpose
Platform infrastructure management - the foundation that everything else depends on.

### Deployment
- **Managed by**: k3s (auto-deployed on every boot)
- **Method**: HelmChart CRD in `/var/lib/rancher/k3s/server/manifests/`
- **Configuration**: `modules/nixos/services/k3s/default.nix:195-237`

### Git Repository
- **Repo**: `https://gitlab.com/usmcamp0811/dotfiles.git`
- **Branch**: `nixos`
- **Path**: `packages/kubernetes-gitops/`

### Manages
All Application CRs live in the `argocd-bootstrap` namespace and manage:
- Self-managed ArgoCD deployment (to `argocd` namespace)
- Platform components:
  - External Secrets Operator + Vault backend
  - MetalLB (LoadBalancer)
  - Traefik (Ingress Controller)
  - Longhorn (Storage)
  - Istio (Service Mesh: base + istiod)
  - Kiali (Service Mesh Observability)
  - Prometheus (Monitoring)

### Why Bootstrap ArgoCD Exists
1. **Auto-recovery**: k3s redeploys it automatically on every restart
2. **Platform stability**: Infrastructure management is isolated from application deployments
3. **Guaranteed availability**: Platform components are always managed even if app ArgoCD fails
4. **Clean separation**: Infrastructure changes don't interfere with application workflows

### Key Files
- **k3s module**: `modules/nixos/services/k3s/default.nix`
- **Root Application**: `packages/kubernetes-gitops/bootstrap/root-app.yaml`
- **Application CRs**: `packages/kubernetes-gitops/clusters/campground/apps/*.yaml`
- **AppProject**: `packages/kubernetes-gitops/clusters/campground/projects/platform-project.yaml`

## Self-Managed ArgoCD (`argocd` namespace)

### Purpose
Application development and non-platform workload management.

### Deployment
- **Managed by**: Bootstrap ArgoCD (via `argocd-self` Application)
- **Method**: Helm chart from `https://argoproj.github.io/argo-helm`
- **Configuration**: `packages/kubernetes-gitops/clusters/campground/apps/argocd-self.yaml`

### Git Repository
- **Currently**: Same repo as bootstrap (`https://gitlab.com/usmcamp0811/dotfiles.git`)
- **Future**: Can be reconfigured to point to:
  - Application repositories
  - Team-specific repositories
  - Separate development repos

### Manages
- Your applications
- Development services
- Non-platform workloads
- Team-specific deployments

### Configuration
The `argocd-self` Application definition:
```yaml
# packages/kubernetes-gitops/clusters/campground/apps/argocd-self.yaml
metadata:
  name: argocd-self
  namespace: argocd-bootstrap  # Application CR lives in bootstrap namespace
spec:
  destination:
    namespace: argocd  # But deploys ArgoCD to argocd namespace
  syncOptions:
    - CreateNamespace=true  # Creates argocd namespace automatically
```

### Why Self-Managed ArgoCD Exists
1. **Separation of concerns**: Apps don't interfere with infrastructure
2. **Different workflows**: App teams can use different GitOps patterns
3. **Independent updates**: Can update app ArgoCD without affecting platform
4. **Multi-tenancy**: Can create different AppProjects for different teams
5. **Repository flexibility**: Can point to different Git repos than platform

### Access
- **UI**: `https://argocd.k8s.aicampground.com` (via Traefik IngressRoute)
- **Service**: `argocd-self-argocd-server.argocd.svc.cluster.local`
- **Authentication**: Authentik OIDC (configured via values.yaml)

## Bootstrap Flow

```
1. k3s starts
   ↓
2. Vault Agent renders bootstrap secrets
   - ArgoCD repo credentials (SSH key)
   - ArgoCD OIDC credentials (Authentik)
   ↓
3. k3s applies manifests in lexical order:
   - 00-argocd-install.yaml (HelmChart CRD → Bootstrap ArgoCD)
   - 10-argocd-repo-secret.yaml (Git credentials)
   - 11-argocd-authentik-oidc.yaml (OIDC credentials)
   - 20-root-app.yaml (Root Application pointing to GitOps repo)
   ↓
4. Bootstrap ArgoCD starts in argocd-bootstrap namespace
   ↓
5. Bootstrap ArgoCD syncs root Application
   ↓
6. Root Application creates Application CRs in argocd-bootstrap namespace:
   - argocd-self (sync-wave: 0) → Deploys to argocd namespace
   - external-secrets (sync-wave: 1)
   - vault-backend (sync-wave: 1)
   - metallb (sync-wave: 2)
   - traefik (sync-wave: 3)
   - etc.
   ↓
7. argocd-self Application deploys Self-Managed ArgoCD
   - Creates argocd namespace
   - Installs ArgoCD Helm chart
   - Configures OIDC with Authentik
   ↓
8. Self-Managed ArgoCD is now available
   - Can be used for application deployments
   - Independent from platform infrastructure
   - Accessible via Traefik IngressRoute
```

## Namespace Summary

| Namespace | Contains | Managed By | Purpose |
|-----------|----------|------------|---------|
| `argocd-bootstrap` | Bootstrap ArgoCD + All Application CRs | k3s (auto-deployed) | Platform infrastructure management |
| `argocd` | Self-Managed ArgoCD | Bootstrap ArgoCD | Application workload management |
| `external-secrets` | External Secrets Operator | Bootstrap ArgoCD | Secret management |
| `metallb-system` | MetalLB | Bootstrap ArgoCD | LoadBalancer IP allocation |
| `traefik-k8s` | Traefik Ingress | Bootstrap ArgoCD | Ingress & TLS termination |
| `longhorn-system` | Longhorn Storage | Bootstrap ArgoCD | Persistent storage |
| `istio-system` | Istio + Kiali | Bootstrap ArgoCD | Service mesh |
| `monitoring` | Prometheus Stack | Bootstrap ArgoCD | Cluster monitoring |

## Application CR Namespace Convention

**Rule**: All Application CRs managed by Bootstrap ArgoCD live in the `argocd-bootstrap` namespace.

**Rationale**:
- Application CRs must be in the same namespace as the ArgoCD instance managing them
- Bootstrap ArgoCD lives in `argocd-bootstrap`, so all its Application CRs must also be in `argocd-bootstrap`
- The Application CR's `spec.destination.namespace` specifies where the application itself deploys

**Example**:
```yaml
# This Application CR lives in argocd-bootstrap namespace
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd-bootstrap  # Application CR is here
spec:
  destination:
    namespace: traefik-k8s  # But deploys Traefik to traefik-k8s namespace
```

## Common Patterns

### Adding a New Platform Component
1. Create Application CR in `packages/kubernetes-gitops/clusters/campground/apps/<name>.yaml`
   - Set `namespace: argocd-bootstrap`
   - Set appropriate sync-wave
2. Create app configuration in `packages/kubernetes-gitops/apps/<name>/`
3. Commit and push to GitOps repo
4. Bootstrap ArgoCD will detect and sync automatically

### Adding an Application (Non-Platform)
1. Configure Self-Managed ArgoCD to point to your app repo (if different from platform repo)
2. Create Application CRs in the `argocd` namespace
3. Or use the Self-Managed ArgoCD UI to create applications

### Updating Bootstrap ArgoCD
- **Don't do this manually!**
- Update the `argocdVersion` in `modules/nixos/services/k3s/default.nix:113`
- Redeploy the k3s configuration

### Updating Self-Managed ArgoCD
- Update the `targetRevision` in `packages/kubernetes-gitops/clusters/campground/apps/argocd-self.yaml:14`
- Commit to GitOps repo
- Bootstrap ArgoCD will sync the change automatically

## Troubleshooting

### Bootstrap ArgoCD not starting
```bash
# Check k3s manifests
ls -la /var/lib/rancher/k3s/server/manifests/

# Check HelmChart CRD
kubectl get helmchart -n kube-system argocd-bootstrap

# Check bootstrap secrets
sudo ls -la /tmp/detsys-vault/
```

### Self-Managed ArgoCD not deploying
```bash
# Check argocd-self Application
kubectl get application -n argocd-bootstrap argocd-self

# Check Application status
kubectl describe application -n argocd-bootstrap argocd-self

# Check if argocd namespace exists
kubectl get namespace argocd
```

### Application CRs in wrong namespace
**Symptom**: Error "namespace argocd does not exist" when syncing

**Cause**: Application CRs were in `argocd` namespace instead of `argocd-bootstrap`

**Fix**: Move Application CRs to `argocd-bootstrap` namespace:
```yaml
metadata:
  namespace: argocd-bootstrap  # Must match where Bootstrap ArgoCD lives
```

## References

- **k3s Module**: `modules/nixos/services/k3s/default.nix`
- **GitOps Package**: `packages/kubernetes-gitops/`
- **k3s Module Docs**: `modules/nixos/services/k3s/README.md`
- **GitOps Baseline Docs**: `packages/kubernetes-gitops/README.md`
- **Bootstrap Notes**: `packages/kubernetes-gitops/bootstrap/NOTES.md`
