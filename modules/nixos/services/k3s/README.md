# K3s Module

NixOS module for deploying and managing K3s clusters with GitOps support.

## Features

- K3s cluster deployment (server or agent mode)
- HA control plane support with token management via Vault
- GitOps bootstrap with ArgoCD
- Vault integration for secrets management
- External Secrets Operator integration

## Configuration

### Basic Server Setup

```nix
fmf.services.k3s = {
  enable = true;
  role = "server";
  clusterInit = true;  # Only on first control plane node
  serverAddr = "10.8.40.49";  # VIP or server IP
};
```

### GitOps Bootstrap

Enable GitOps to automatically deploy ArgoCD and bootstrap cluster management:

```nix
fmf.services.k3s.gitops = {
  enable = true;
  repoURL = "https://gitlab.com/usmcamp0811/dotfiles.git";
  targetRevision = "nixos";
  clusterName = "campground";
  argocdVersion = "7.7.0";
  enableAuthentikOIDC = true;  # Default: true - enables automatic Vault K8s auth setup
};
```

#### Authentik OIDC for ArgoCD

When `gitops.enableAuthentikOIDC = true` (the default), the k3s preStart script automatically:
- Waits for the `external-secrets` namespace and `vault-auth` ServiceAccount (deployed by ArgoCD)
- Creates the `vault-auth-delegator` ClusterRoleBinding
- Configures Vault's Kubernetes authentication backend
- Creates the Vault role for external-secrets

This enables ExternalSecrets to sync ArgoCD OIDC credentials from Vault automatically.

Set to `false` if you don't want Authentik OIDC for ArgoCD or don't use External Secrets.

## Vault Integration

This module integrates with Vault for secrets management through the External Secrets Operator.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ External (not in K8s cluster)                               │
│                                                             │
│  ┌──────────────┐                                          │
│  │  Vault       │  (vm-vault, 10.8.0.3:8200)               │
│  │              │                                          │
│  │  AppRole ────┼──> Used by control plane hosts          │
│  │  K8s Auth ───┼──> Used by pods via ServiceAccount      │
│  └──────────────┘                                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ (1) Manual one-time setup
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster                                          │
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │ external-secrets namespace                        │     │
│  │                                                   │     │
│  │  ServiceAccount: vault-auth ──────────────────┐  │     │
│  │                                                │  │     │
│  │  ClusterSecretStore: vault-backend             │  │     │
│  │    ├─ Uses Kubernetes auth                     │  │     │
│  │    └─ References: vault-auth ServiceAccount ───┘  │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │ argocd namespace                                  │     │
│  │                                                   │     │
│  │  ExternalSecret: argocd-authentik-oidc            │     │
│  │    └─ Syncs from: vault-backend                   │     │
│  └───────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### One-Time Vault Kubernetes Auth Setup

**CRITICAL**: After deploying a new cluster with GitOps enabled, you **MUST** manually configure Vault's Kubernetes authentication backend. This is a one-time operation that connects Vault (running outside the cluster) to the Kubernetes API.

**Why manual?** Vault runs outside the K8s cluster (vm-vault), so it can't be automated with a K8s Job without creating a chicken-and-egg problem with credentials.

**When to do this:** After the cluster is deployed and ArgoCD has synced the `vault-backend` Application (sync wave 1), but before any ExternalSecrets will work.

#### Prerequisites

1. K3s cluster is running
2. ArgoCD is deployed and has synced
3. `external-secrets` namespace exists
4. `vault-auth` ServiceAccount exists in `external-secrets` namespace
5. You have Vault access (root token or sufficient permissions)

#### Option A: Using the vault-k8s-init Script (Recommended)

The easiest approach is to use the pre-built `vault-k8s-init` script from the fmf flake.

**1. SSH to a control plane node (e.g., vm-k8s-control-0)**

```bash
ssh admin@10.8.40.50
```

**2. Set environment variables**

```bash
export VAULT_ADDR=http://10.8.0.3:8200
export VAULT_KV_PATH=secret/campground
export VAULT_KV_VERSION=v2
export VAULT_POLICY=campground
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export HOSTNAME=vm-k8s-control-0
```

**3. Run the vault-k8s-init script**

This script handles all the setup automatically, including:
- Creating the vault-auth ServiceAccount
- Generating the K8s token and getting the CA cert
- Configuring Vault Kubernetes auth
- Creating the external-secrets role
- Creating the ClusterSecretStore

```bash
nix run /config#vault-k8s-init.script
```

**4. Verify the configuration**

```bash
# Check ClusterSecretStore status
kubectl get clustersecretstore vault-backend

# Check for any ExternalSecrets and their sync status
kubectl get externalsecrets -A
```

#### Option B: Manual Step-by-Step (If you need more control)

**1. SSH to a control plane node**

```bash
ssh admin@10.8.40.50
```

**2. Set environment variables**

```bash
export VAULT_ADDR=http://10.8.0.3:8200
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

**3. Login to Vault**

```bash
vault login
# Enter your Vault token
```

**4. Verify the vault-auth ServiceAccount exists**

```bash
kubectl get serviceaccount -n external-secrets vault-auth
```

**5. Create a Kubernetes token for the vault-auth ServiceAccount**

```bash
kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt
```

**6. Get the Kubernetes cluster CA certificate**

```bash
kubectl -n kube-system get configmap kube-root-ca.crt \
  -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt
```

**7. Configure Vault Kubernetes auth backend**

```bash
# Enable the kubernetes auth method (skip if already enabled)
vault auth enable kubernetes 2>/dev/null || echo "Kubernetes auth already enabled"

# Configure Vault to talk to the Kubernetes API
vault write auth/kubernetes/config \
  token_reviewer_jwt=@/tmp/token.jwt \
  kubernetes_host="https://10.8.40.49:6443" \
  kubernetes_ca_cert=@/tmp/ca.crt \
  disable_iss_validation=true
```

**8. Create the external-secrets Vault role**

This role allows the `vault-auth` ServiceAccount to authenticate and read secrets:

```bash
vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names="vault-auth" \
  bound_service_account_namespaces="*" \
  policies="campground" \
  ttl=24h
```

**9. Clean up temporary files**

```bash
rm -f /tmp/token.jwt /tmp/ca.crt
```

**10. Verify the configuration**

Test that the ClusterSecretStore can authenticate:

```bash
# Check ClusterSecretStore status
kubectl get clustersecretstore vault-backend

# Check for any ExternalSecrets and their sync status
kubectl get externalsecrets -A
```

#### Troubleshooting

**ClusterSecretStore shows "SecretSyncedError"**
- Verify Vault Kubernetes auth is configured: `vault read auth/kubernetes/config`
- Check the role exists: `vault read auth/kubernetes/role/external-secrets`
- Verify the ServiceAccount exists: `kubectl get sa -n external-secrets vault-auth`

**ExternalSecrets not syncing**
- Check ExternalSecret status: `kubectl describe externalsecret -n <namespace> <name>`
- Verify the secret path exists in Vault: `vault kv get secret/campground/<path>`
- Check External Secrets Operator logs: `kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets`

**Need to refresh the token**
The token_reviewer_jwt expires. To refresh:
```bash
# Create a new token
kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt

# Update Vault config (keep other settings the same)
vault write auth/kubernetes/config \
  token_reviewer_jwt=@/tmp/token.jwt \
  kubernetes_host="https://10.8.40.49:6443" \
  kubernetes_ca_cert=@/tmp/ca.crt \
  disable_iss_validation=true

rm -f /tmp/token.jwt
```

## Token Management

### Cluster Init Node (clusterInit = true)

The first control plane node:
- Generates the K3s cluster token
- Stores the token in Vault at `vault-path` (default: `secret/campground/k3s`)
- Stores the kubeconfig with the correct API server address

### Joining Nodes (clusterInit = false)

Other control plane nodes and agents:
- Retrieve the cluster token from Vault via vault-agent
- Join the cluster using the token
- Token is rendered to `/tmp/detsys-vault/k3s-token` by vault-agent

## Module Options

See `default.nix` for complete options. Key options:

- `enable` - Enable K3s
- `role` - "server" or "agent"
- `clusterInit` - Whether this node initializes the cluster
- `serverAddr` - K3s API server address (for agents and joining servers)
- `snapshotter` - Container snapshotter ("fuse-overlayfs" for MicroVMs)
- `gitops.enable` - Enable ArgoCD bootstrap
- `gitops.enableAuthentikOIDC` - Enable automatic Vault K8s auth setup for ArgoCD OIDC (default: `true`)
- `vault-path` - Vault path for K3s secrets (default: `secret/campground/k3s`)

## Example: HA Control Plane Setup

**Control Plane Node 0 (bootstrap):**
```nix
fmf.services.k3s = {
  enable = true;
  role = "server";
  clusterInit = true;
  serverAddr = "10.8.40.49";  # VIP
  gitops.enable = true;
  vault-path = "secret/campground/k3s";
};
```

**Control Plane Nodes 1 & 2 (joiners):**
```nix
fmf.services.k3s = {
  enable = true;
  role = "server";
  clusterInit = false;
  serverAddr = "10.8.40.49";  # VIP
  vault-path = "secret/campground/k3s";
};
```

**After deployment:**
1. Node 0 starts, creates cluster, stores token in Vault
2. Nodes 1 & 2 retrieve token from Vault and join
3. ArgoCD deploys and syncs cluster configuration
4. **Manually configure Vault Kubernetes auth** (see above)
5. ExternalSecrets begin syncing from Vault

## Files Generated

- `/etc/rancher/k3s/k3s.yaml` - Kubeconfig (generated by K3s)
- `/var/lib/rancher/k3s/server/node-token` - Cluster join token (from Vault on joiners)
- `/tmp/detsys-vault/k3s-token` - Token rendered by vault-agent (joiners)
- `/tmp/detsys-vault/argocd-repo-secret.yaml` - ArgoCD repo credentials (bootstrap node)

## Related Modules

- `fmf.services.k8s-control-plane` - Higher-level module for HA control plane setup
- `fmf.services.vault-agent` - Vault agent integration
- `fmf.packages.kubernetes-gitops` - GitOps repository structure and manifests
