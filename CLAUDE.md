# Claude Context: fmf-flake Project

This document provides context for Claude (AI assistant) when working on this codebase.

## Project Overview

**fmf-flake** is a NixOS flake-based infrastructure-as-code repository for managing the "Campground" homelab environment. It includes:

- NixOS system configurations
- Kubernetes (k3s) cluster management
- GitOps with ArgoCD
- Vault-based secrets management
- Custom NixOS modules and packages

## Repository Structure

```
fmf-flake/
├── flake.nix                    # Main flake entry point
├── flake.lock                   # Flake dependencies lock file
├── modules/
│   └── nixos/
│       └── services/
│           ├── k3s/             # K3s cluster management module
│           └── vault-agent/     # Vault agent integration
├── packages/
│   ├── kubernetes-gitops/       # GitOps manifests and ArgoCD config
│   ├── websites/                # Website packages
│   └── learning-*/              # Learning projects
├── hosts/                       # Per-host NixOS configurations (if exists)
└── docs/                        # Documentation

Key Paths:
- K3s Module: modules/nixos/services/k3s/default.nix
- GitOps: packages/kubernetes-gitops/
- ArgoCD Architecture: packages/kubernetes-gitops/ARGOCD-ARCHITECTURE.md
```

## Key Technologies

- **Nix/NixOS**: Declarative system configuration and package management
- **k3s**: Lightweight Kubernetes distribution
- **ArgoCD**: GitOps continuous delivery for Kubernetes
- **Vault**: Secrets management (external to k3s cluster)
- **External Secrets Operator**: Syncs secrets from Vault to Kubernetes
- **Traefik**: Ingress controller with automatic TLS via Let's Encrypt
- **MetalLB**: Bare-metal LoadBalancer implementation
- **Istio**: Service mesh
- **Longhorn**: Distributed block storage
- **Prometheus**: Monitoring and alerting

## ArgoCD Architecture

This project uses **two separate ArgoCD instances**:

### 1. Bootstrap ArgoCD (`argocd-bootstrap` namespace)
- **Purpose**: Platform infrastructure management
- **Deployed by**: k3s (auto-deployed on every boot via HelmChart CRD)
- **Repository**: `https://gitlab.com/usmcamp0811/dotfiles.git` (branch: `nixos`)
- **Manages**: All platform components (MetalLB, Traefik, Istio, External Secrets, Longhorn, etc.)
- **Application CRs**: All live in `argocd-bootstrap` namespace

### 2. Self-Managed ArgoCD (`argocd` namespace)
- **Purpose**: Application development and non-platform workloads
- **Deployed by**: Bootstrap ArgoCD (via `argocd-self` Application)
- **Repository**: Currently same as bootstrap, but can be reconfigured for different repos
- **Manages**: Application workloads, dev services, non-infrastructure apps
- **Access**: `https://argocd.k8s.aicampground.com`

**Important**: All Application CRs managed by Bootstrap ArgoCD must be in the `argocd-bootstrap` namespace, NOT the `argocd` namespace.

For detailed architecture, see: `packages/kubernetes-gitops/ARGOCD-ARCHITECTURE.md`

## Key Concepts

### Bootstrap Flow
1. k3s starts
2. Vault Agent renders bootstrap secrets to `/var/lib/rancher/k3s/server/manifests/`
3. k3s auto-applies manifests (ArgoCD install, repo credentials, root app)
4. Bootstrap ArgoCD starts and syncs from Git
5. Bootstrap ArgoCD deploys all platform components including Self-Managed ArgoCD
6. Self-Managed ArgoCD becomes available for application workloads

### Namespace Conventions
- `argocd-bootstrap`: Bootstrap ArgoCD + all its Application CRs
- `argocd`: Self-Managed ArgoCD (deployed by Bootstrap)
- Platform components: Each in their own namespace (e.g., `traefik-k8s`, `metallb-system`, `istio-system`)

### Application CR Placement Rule
**Application CRs must live in the same namespace as the ArgoCD instance managing them.**

Example:
```yaml
# This Application CR lives in argocd-bootstrap namespace
# because Bootstrap ArgoCD manages it
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd-bootstrap  # Application CR location
spec:
  destination:
    namespace: traefik-k8s  # Where Traefik actually deploys
```

### Secret Management
- **Bootstrap Secrets**: Rendered by Vault Agent on k3s nodes (ArgoCD repo credentials, OIDC secrets)
- **Runtime Secrets**: Managed by External Secrets Operator + Vault ClusterSecretStore
- **Never committed to Git**: All secrets come from Vault

### Vault Integration
- **Vault Instance**: External to k3s cluster (typically `vm-vault` at `10.8.0.3:8200`)
- **Authentication Methods**:
  - AppRole: Used by k3s control plane hosts via Vault Agent
  - Kubernetes Auth: Used by pods via ServiceAccount (External Secrets Operator)
- **One-time setup**: Vault Kubernetes auth must be manually configured after cluster bootstrap

## Common Tasks

### Modifying Platform Infrastructure
1. Edit files in `packages/kubernetes-gitops/`
2. Ensure Application CRs are in `argocd-bootstrap` namespace
3. Commit and push to GitOps repo
4. Bootstrap ArgoCD auto-syncs changes

### Adding a New Platform Component
1. Create Application CR: `packages/kubernetes-gitops/clusters/campground/apps/<name>.yaml`
   - Set `metadata.namespace: argocd-bootstrap`
   - Set appropriate sync-wave for ordering
2. Create app config: `packages/kubernetes-gitops/apps/<name>/`
3. Commit to Git
4. Bootstrap ArgoCD will detect and deploy

### Updating k3s Configuration
1. Edit `modules/nixos/services/k3s/default.nix`
2. Rebuild NixOS configuration on control plane nodes
3. k3s will restart with new configuration

### Adding Application Workloads (Non-Platform)
- Use Self-Managed ArgoCD in `argocd` namespace
- Create Application CRs via UI or in `argocd` namespace
- Can point to different Git repositories

## File Patterns

### NixOS Modules
- Located in `modules/nixos/`
- Use the `fmf` namespace for options (e.g., `fmf.services.k3s`)
- Follow Nix module structure with `options` and `config` sections

### GitOps Manifests
- Located in `packages/kubernetes-gitops/`
- Structure:
  - `bootstrap/`: Root app template and notes
  - `clusters/<cluster-name>/`: Cluster-specific apps and projects
  - `apps/<app-name>/`: App-specific values and manifests

### Application CRs
- All managed by Bootstrap ArgoCD live in `argocd-bootstrap` namespace
- Use sync-waves for ordering (0 = first, higher numbers = later)
- Multi-source pattern for Helm charts with values from Git

## Important Reminders for Claude

1. **Namespace Convention**: Application CRs managed by Bootstrap ArgoCD go in `argocd-bootstrap`, not `argocd`
2. **Two ArgoCDs**: Don't confuse Bootstrap (infrastructure) with Self-Managed (applications)
3. **No Secrets in Git**: All secrets come from Vault, never commit secrets
4. **Read First**: Always read files before editing (required by Edit tool)
5. **Bootstrap Changes**: Changes to Bootstrap ArgoCD require NixOS rebuild, not just Git commits
6. **Sync Waves**: Use appropriate sync-waves for deployment ordering
7. **Multi-Source**: Helm-based apps use multi-source pattern (chart + values ref)

## Troubleshooting Patterns

### "namespace argocd does not exist" Error
**Cause**: Application CRs in wrong namespace
**Fix**: Move Application CRs to `argocd-bootstrap` namespace

### ArgoCD Not Syncing
1. Check Application status: `kubectl get application -n argocd-bootstrap <name>`
2. Check for sync errors: `kubectl describe application -n argocd-bootstrap <name>`
3. Check ArgoCD logs: `kubectl logs -n argocd-bootstrap deployment/argocd-server`

### Vault Integration Issues
1. Verify ClusterSecretStore: `kubectl get clustersecretstore vault-backend`
2. Check External Secrets Operator logs: `kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets`
3. Verify Vault Kubernetes auth is configured: `vault read auth/kubernetes/config`

### k3s Bootstrap Issues
1. Check manifests directory: `ls -la /var/lib/rancher/k3s/server/manifests/`
2. Check HelmChart CRD: `kubectl get helmchart -n kube-system`
3. Check vault-agent rendered secrets: `sudo ls -la /tmp/detsys-vault/`

## Git Repository

- **Remote**: `https://gitlab.com/usmcamp0811/dotfiles.git`
- **Branch**: `nixos`
- **Bootstrap Access**: Via SSH deploy key stored in Vault

## Useful Commands

```bash
# Build GitOps package
nix build .#gitops

# Build root app only
nix build .#gitops-root-app

# Check k3s status
kubectl get nodes
kubectl get applications -n argocd-bootstrap

# Verify Vault integration
kubectl get clustersecretstore
kubectl get externalsecrets -A

# Access ArgoCD UI
# Bootstrap: kubectl port-forward -n argocd-bootstrap svc/argocd-server 8080:80
# Self-Managed: https://argocd.k8s.aicampground.com
```

## Documentation References

- **ArgoCD Architecture**: `packages/kubernetes-gitops/ARGOCD-ARCHITECTURE.md`
- **K3s Module**: `modules/nixos/services/k3s/README.md`
- **GitOps Baseline**: `packages/kubernetes-gitops/README.md`
- **Bootstrap Notes**: `packages/kubernetes-gitops/bootstrap/NOTES.md`
- **Deployment Guide**: `packages/kubernetes-gitops/DEPLOYMENT.md`

## Recent Changes (2026-02-04)

- Fixed namespace issue: Moved all Application CRs from `argocd` to `argocd-bootstrap` namespace
- Updated AppProject to `argocd-bootstrap` namespace
- Fixed Traefik IngressRoute to reference correct service name: `argocd-self-argocd-server`
- Created comprehensive architecture documentation

## Design Principles

1. **Declarative Everything**: Use Nix and GitOps for all configuration
2. **Immutable Infrastructure**: NixOS + GitOps = reproducible systems
3. **Separation of Concerns**: Platform (bootstrap) vs Applications (self-managed)
4. **Secrets Outside Git**: Vault for all sensitive data
5. **Auto-Recovery**: k3s auto-deploys Bootstrap ArgoCD on every boot
6. **GitOps Single Source of Truth**: Git repo is authoritative for cluster state

## When Working on This Project

1. **Check namespace carefully** when working with ArgoCD resources
2. **Understand the bootstrap flow** before making infrastructure changes
3. **Test changes** in a safe environment if possible
4. **Document significant changes** in relevant README files
5. **Follow Nix best practices** for module development
6. **Use sync-waves** appropriately for deployment ordering
7. **Never commit secrets** - always use Vault integration

## Contact & Context

- **Owner**: @usmcamp0811 (Matt Camp)
- **Environment**: Homelab "Campground" cluster
- **Primary Use**: Learning, experimentation, personal infrastructure
- **Scale**: Small (typically 3-5 nodes)

---

**For Claude**: When asked about ArgoCD, namespaces, or deployment issues, always refer to this document and the detailed architecture doc at `packages/kubernetes-gitops/ARGOCD-ARCHITECTURE.md`.
