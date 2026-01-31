# GitOps Deployment Guide

This guide explains how to deploy a fresh k3s cluster with GitOps baseline using this implementation.

## Prerequisites

1. **Vault instance** accessible at `http://10.8.0.3:8200` (or configured address)
2. **Vault paths configured** with required secrets:
   - `secret/campground/k3s` - Contains `node_token` for cluster join
   - `secret/campground/argocd/repo` - Contains Git repo credentials:
     - `url` - Git repository URL
     - `ssh_private_key` - SSH private key for repo access
3. **AppRole authentication** configured in Vault for k3s nodes
4. **Git repository** accessible (public or via SSH key)

## Deployment Steps

### 1. Enable GitOps in NixOS Configuration

For a k3s control plane node, enable GitOps bootstrap:

```nix
{
  fmf.services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;  # For first control plane node

    # Enable GitOps bootstrap
    gitops = {
      enable = true;
      repoURL = "https://github.com/usmcamp0811/dotfiles.git";
      targetRevision = "nixos";
      clusterName = "campground";
      argocdVersion = "7.7.0";
    };

    # Vault configuration
    vault-address = "http://10.8.0.3:8200";
    vault-path = "secret/campground/k3s";
    kvVersion = "v2";
  };
}
```

Or for k8s-control-plane module:

```nix
{
  fmf.services.k8s-control-plane = {
    enable = true;
    nodeId = 0;  # 0, 1, or 2
    vip = "10.8.40.49";
    # ... other settings
  };

  # Enable GitOps on the k3s service
  fmf.services.k3s.gitops = {
    enable = true;
    repoURL = "https://github.com/usmcamp0811/dotfiles.git";
    targetRevision = "nixos";
    clusterName = "campground";
  };
}
```

### 2. Deploy the Configuration

```bash
nixos-rebuild switch
```

### 3. Bootstrap Flow

When the system boots:

1. **Vault Agent starts** and authenticates using AppRole
2. **Vault Agent renders bootstrap secrets** to `/var/lib/rancher/k3s/server/manifests/`:
   - `10-argocd-repo-secret.yaml` - Git repository credentials
3. **k3s service starts** and applies manifests in order:
   - `00-argocd-install.yaml` - ArgoCD Helm chart (via k3s HelmChart CRD)
   - `10-argocd-repo-secret.yaml` - Repository credentials secret
   - `20-root-app.yaml` - Root Application pointing to GitOps repo
4. **ArgoCD starts** and processes the root Application
5. **ArgoCD syncs** all child Applications from `packages/gitops/clusters/campground/apps/`:
   - Wave 0: `argocd-self`, `storage`
   - Wave 1: `external-secrets`, `vault-backend`
   - Wave 2: `metallb`
   - Wave 3: `traefik`
6. **Steady state** - All applications are managed by ArgoCD

### 4. Verification

Wait for ArgoCD to start (may take 2-3 minutes):

```bash
# Wait for ArgoCD deployment
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Check root application exists
kubectl get application -n argocd root

# Wait for all applications to sync
kubectl wait --for=jsonpath='{.status.sync.status}'=Synced --timeout=600s application --all -n argocd
```

Check all applications are healthy:

```bash
kubectl get applications -n argocd
```

Expected output:
```
NAME                SYNC STATUS   HEALTH STATUS
root                Synced        Healthy
argocd-self         Synced        Healthy
storage             Synced        Healthy
external-secrets    Synced        Healthy
vault-backend       Synced        Healthy
metallb             Synced        Healthy
traefik             Synced        Healthy
```

### 5. Verify Components

#### Storage

```bash
kubectl get storageclass
# Should show 'glusterfs (default)'

# Test PVC creation
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
# Should show Pending (waiting for manual PV creation) or Bound if PV exists
kubectl delete pvc test-pvc
```

#### MetalLB

```bash
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
kubectl get svc -n traefik-k8s traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Should return an IP from 10.8.40.100-10.8.40.255 range
```

#### External Secrets

```bash
kubectl get clustersecretstore vault-backend
kubectl get externalsecret -n traefik-k8s cloudflare-api-token
kubectl get secret -n traefik-k8s cloudflare-api-token
```

#### Traefik

```bash
kubectl get svc -n traefik-k8s traefik
# Should have LoadBalancer IP from MetalLB

kubectl get ingressroute -n argocd argocd-server
# Check TLS cert is being issued

# Check ACME logs
kubectl logs -n traefik-k8s -l app.kubernetes.io/name=traefik | grep -i acme
```

#### ArgoCD UI

Access ArgoCD:

```bash
# Get LoadBalancer IP
TRAEFIK_IP=$(kubectl get svc -n traefik-k8s traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Get initial admin password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Access UI
echo "ArgoCD UI: https://argocd.k8s.aicampground.com"
echo "or https://$TRAEFIK_IP (with host header)"
```

## Troubleshooting

### ArgoCD not starting

Check k3s manifests were applied:

```bash
ls -la /var/lib/rancher/k3s/server/manifests/
# Should see:
# 00-argocd-install.yaml
# 10-argocd-repo-secret.yaml
# 20-root-app.yaml
```

Check ArgoCD pods:

```bash
kubectl get pods -n argocd
kubectl logs -n argocd deployment/argocd-server
```

### Root Application not syncing

Check repository credentials:

```bash
kubectl get secret -n argocd private-repo -o yaml
# Should exist and contain sshPrivateKey

kubectl describe application -n argocd root
# Check for auth errors
```

Check ArgoCD can reach the repo:

```bash
kubectl logs -n argocd deployment/argocd-repo-server | grep -i error
```

### Vault Agent not rendering secrets

Check Vault Agent service:

```bash
systemctl status vault-agent-k3s.service
journalctl -u vault-agent-k3s.service -n 100
```

Verify templates rendered:

```bash
ls -la /var/lib/rancher/k3s/server/manifests/10-argocd-repo-secret.yaml
cat /var/lib/rancher/k3s/server/manifests/10-argocd-repo-secret.yaml | head -20
# Should contain valid Kubernetes Secret YAML (no Vault template placeholders)
```

### Applications stuck in Progressing/Degraded

Check specific application:

```bash
kubectl describe application -n argocd <app-name>
kubectl get application -n argocd <app-name> -o yaml
```

Check deployed resources:

```bash
# For metallb example
kubectl get all -n metallb-system
kubectl logs -n metallb-system deployment/metallb-controller
```

Force sync:

```bash
kubectl patch application -n argocd <app-name> --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}'
```

## Disaster Recovery

If the cluster needs to be completely rebuilt:

1. Destroy the k3s cluster (or rebuild the node)
2. Redeploy NixOS configuration with same settings
3. k3s will bootstrap automatically using manifests
4. ArgoCD will re-sync all applications from Git
5. No manual `kubectl apply` commands required

All state is either:
- In Vault (secrets)
- In Git (desired state)
- On GlusterFS storage (persistent data)

## Updating Applications

### Update Application Versions

1. Edit the relevant Application YAML in `packages/gitops/clusters/campground/apps/`
2. Or edit values in `packages/gitops/apps/<app-name>/`
3. Commit and push to Git
4. ArgoCD auto-syncs (or manually sync via UI/CLI)

### Update ArgoCD Itself

Edit `packages/gitops/apps/argocd/values.yaml` or the chart version in `clusters/campground/apps/argocd-self.yaml`, commit, push. ArgoCD will self-update.

### Update Bootstrap ArgoCD Version

Edit NixOS configuration:

```nix
fmf.services.k3s.gitops.argocdVersion = "7.8.0";
```

Run `nixos-rebuild switch`. The ArgoCD HelmChart manifest will be updated and k3s will reconcile.

## Adding New Applications

1. Create Application manifest in `packages/gitops/clusters/campground/apps/new-app.yaml`
2. Add app-specific resources in `packages/gitops/apps/new-app/`
3. Update `packages/gitops/clusters/campground/kustomization.yaml` to include the new app
4. Commit and push
5. ArgoCD auto-detects and syncs

## Security Notes

- Bootstrap secrets (repo credentials) are NEVER in Git
- Bootstrap secrets are only on k3s nodes, rendered by Vault Agent
- Runtime secrets use External Secrets + Vault ClusterSecretStore
- All secrets rotation happens in Vault; External Secrets re-fetches automatically
- ArgoCD has read-only access to Git (deploy key)
- Cluster admin access via ArgoCD UI (protect with SSO in production)
