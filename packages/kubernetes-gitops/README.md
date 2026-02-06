# GitOps Baseline for Campground Cluster

This package provides a Nix-based GitOps baseline for deploying and managing the Campground k3s cluster using ArgoCD.

## Overview

This GitOps implementation follows a bootstrap pattern where:

1. **k3s boot-time manifests** initialize the cluster with:
   - ArgoCD installation
   - Bootstrap secrets (rendered by Vault Agent)
   - Root Application pointing to this GitOps repository

2. **ArgoCD manages everything else** after initial boot:
   - Self-management (ArgoCD manages its own chart)
   - Storage (Gluster CSI + default StorageClass)
   - External Secrets + Vault ClusterSecretStore
   - MetalLB (LoadBalancer implementation)
   - Traefik (Ingress + Cloudflare DNS-01 ACME)

## Architecture

### Bootstrap Flow

```
k3s Node Boot
  ↓
Vault Agent writes bootstrap secrets → /var/lib/rancher/k3s/server/manifests/
  ↓
k3s auto-applies manifests:
  - 00-argocd-install.yaml (ArgoCD installation)
  - 10-argocd-repo-secret.yaml (Git repo credentials from Vault)
  - 20-root-app.yaml (Root Application from Nix package)
  ↓
ArgoCD starts and syncs from Git
  ↓
ArgoCD deploys baseline apps:
  - argocd-self (self-management)
  - storage (Gluster CSI)
  - external-secrets + vault-backend
  - metallb
  - traefik
```

### Secret Management

**Bootstrap Secrets** (pre-External Secrets, rendered by Vault Agent):
- ArgoCD Git repository credentials (SSH deploy key or HTTPS token)
- Required for ArgoCD to fetch the GitOps repository

**Runtime Secrets** (post-External Secrets, via ClusterSecretStore):
- Cloudflare API token (for Traefik DNS-01 ACME)
- Any application secrets

Bootstrap secrets are materialized as Kubernetes `Secret` YAML manifests by Vault Agent and placed in the k3s manifests directory before k3s starts.

## Repository Structure

```
packages/gitops/
├── default.nix              # Nix package definition
├── README.md               # This file
├── bootstrap/
│   ├── root-app.yaml       # Template for root Application
│   └── NOTES.md            # Bootstrap mechanism documentation
├── clusters/
│   └── campground/
│       ├── kustomization.yaml
│       ├── projects/
│       │   └── platform-project.yaml
│       └── apps/
│           ├── argocd-self.yaml
│           ├── storage.yaml
│           ├── external-secrets.yaml
│           ├── vault-backend.yaml
│           ├── metallb.yaml
│           └── traefik.yaml
└── apps/
    ├── argocd/
    │   └── values.yaml
    ├── storage/
    │   ├── values.yaml
    │   └── storageclass.yaml
    ├── external-secrets/
    │   ├── values.yaml
    │   ├── vault-auth-serviceaccount.yaml
    │   ├── clustersecretstore.yaml
    │   └── externalsecret-cloudflare-token.yaml
    ├── metallb/
    │   ├── values.yaml
    │   ├── ippool.yaml
    │   └── l2advertisement.yaml
    └── traefik/
        ├── values.yaml
        └── ingressroutes/
            └── argocd-server.yaml
```

## Building with Nix

### Output A: Root Application YAML

```bash
# Build just the root app manifest
nix build .#gitops-root-app

# Result is a single YAML file
cat result/root-app.yaml
```

### Output B: Full GitOps Tree

```bash
# Build the complete GitOps tree
nix build .#gitops

# Result is the entire directory structure
ls -la result/
```

### Parameters

The package accepts these parameters (via flake-level config or function args):

- `repoURL`: Git repository URL (default: determined from flake)
- `targetRevision`: Git branch/tag (default: "nixos")
- `clusterName`: Cluster name (default: "campground")
- `clusterPath`: Path within repo (default: "packages/gitops/clusters/campground")

## k3s Integration

### Manifests Directory

k3s server nodes use: `/var/lib/rancher/k3s/server/manifests`

Files in this directory are automatically applied at boot in lexical order.

### Required Bootstrap Files

1. **00-argocd-install.yaml** - ArgoCD installation (from upstream or HelmChart CRD)
2. **10-argocd-repo-secret.yaml** - Git repo credentials (from Vault Agent)
3. **20-root-app.yaml** - Root Application (from this Nix package)

### NixOS Module Integration

The `fmf.services.k3s` module is extended to:
- Copy the root-app.yaml from the Nix package output into the manifests directory
- Ensure ArgoCD install manifests are present
- Configure Vault Agent to render bootstrap secrets

## Vault Agent Bootstrap Secrets

### Required Vault Paths

Vault Agent templates read from these paths:

- **K3s cluster token**: `secret/campground/k3s` (field: `node_token`)
- **ArgoCD Git repo SSH key**: `secret/campground/argocd/repo` (fields: `ssh_private_key`, `known_hosts`)

Or for HTTPS:
- **ArgoCD Git repo token**: `secret/campground/argocd/repo` (field: `token`)

### Rendered Manifests

Vault Agent writes these files to `/var/lib/rancher/k3s/server/manifests/`:

```yaml
# 10-argocd-repo-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
type: Opaque
stringData:
  sshPrivateKey: |
    {{ with secret "secret/campground/argocd/repo" }}
    {{ .Data.data.ssh_private_key }}
    {{ end }}
```

## Baseline Components

### ArgoCD Self-Management

ArgoCD manages its own Helm chart via a multi-source Application:
- Chart source: Argo Helm repository
- Values source: `apps/argocd/values.yaml` in this repo
- Pinned chart version for stability

### Storage (Gluster CSI)

Uses a proper CSI driver (not deprecated in-tree plugin):
- CSI driver: TBD (compatible with k3s version)
- Default StorageClass annotated with `storageclass.kubernetes.io/is-default-class: "true"`

### External Secrets + Vault Backend

- External Secrets Operator chart (pinned version)
- ServiceAccount for Vault authentication
- ClusterSecretStore pointing to external Vault instance
- ExternalSecret for Cloudflare token (consumed by Traefik)

### MetalLB

- MetalLB chart (pinned version)
- IPAddressPool manifest for IP range
- L2Advertisement manifest for ARP/NDP
- No webhook deletions or workarounds

### Traefik

- Traefik chart (pinned version)
- LoadBalancer service (uses MetalLB)
- Persistent volume for ACME storage
- Cloudflare DNS-01 resolver configuration
- Cloudflare token from ExternalSecret
- IngressRoute for ArgoCD UI (optional)

## Verification

### Fresh Cluster Bootstrap

1. Deploy k3s node with NixOS configuration
2. Vault Agent renders bootstrap secrets
3. k3s applies manifests from `/var/lib/rancher/k3s/server/manifests/`
4. Wait for ArgoCD to start: `kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd`
5. Verify root app: `kubectl get application -n argocd root`

### Application Health

Check all baseline applications are Synced and Healthy:

```bash
kubectl get applications -n argocd
```

Expected output:
```
NAME                SYNC STATUS   HEALTH STATUS
argocd-self         Synced        Healthy
storage             Synced        Healthy
external-secrets    Synced        Healthy
vault-backend       Synced        Healthy
metallb             Synced        Healthy
traefik             Synced        Healthy
```

### MetalLB LoadBalancer

```bash
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Should return an IP from the MetalLB pool.

### External Secrets

```bash
kubectl get clustersecretstore vault -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Should output: True

kubectl get externalsecret -n traefik cloudflare-token -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Should output: True
```

### Traefik TLS Certificate

```bash
kubectl get ingressroute -n argocd argocd-server -o yaml
# Check for TLS configuration

kubectl logs -n traefik -l app.kubernetes.io/name=traefik | grep -i acme
# Should show successful certificate acquisition
```

### Storage Default Class

```bash
kubectl get storageclass
# Should show one with (default) annotation

kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc
# Should show Bound status

kubectl delete pvc test-pvc
```

## Security Notes

- Bootstrap secrets are NEVER committed to Git
- Bootstrap secrets are only rendered by Vault Agent on the k3s nodes
- File permissions on bootstrap secret manifests should be restrictive (0600)
- Runtime secrets use External Secrets + Vault ClusterSecretStore
- No secrets are stored in the GitOps repository YAMLs

## Maintenance

### Updating ArgoCD Version

Edit `apps/argocd/values.yaml` to pin a new chart version. ArgoCD will self-update via the `argocd-self` Application.

### Adding New Applications

1. Create app definition in `clusters/campground/apps/<app-name>.yaml`
2. Create app manifests/values in `apps/<app-name>/`
3. Commit and push to Git
4. ArgoCD will detect and sync automatically (auto-sync enabled)

### Disaster Recovery

If the cluster needs to be rebuilt:

1. Deploy fresh k3s node with NixOS config
2. Bootstrap secrets are re-rendered by Vault Agent
3. k3s re-applies manifests
4. ArgoCD re-syncs all applications from Git

No manual kubectl apply commands required beyond initial cluster deployment.
