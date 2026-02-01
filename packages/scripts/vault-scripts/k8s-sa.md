# Vault Kubernetes Auth Setup

Complete guide for configuring Vault's Kubernetes authentication backend to work with External Secrets Operator.

## Prerequisites

- Vault is running and accessible (e.g., http://10.8.0.3:8200)
- Kubernetes cluster is running with External Secrets Operator installed
- `vault-auth` ServiceAccount exists in `external-secrets` namespace
- You have admin access to both Vault and Kubernetes

## Quick Setup

### 1. Create Required ClusterRoleBinding

The `vault-auth` ServiceAccount **must** have the `system:auth-delegator` ClusterRole to allow Vault to perform token reviews.

```bash
kubectl create clusterrolebinding vault-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=external-secrets:vault-auth
```

### 2. Get Kubernetes Credentials

```bash
# Create a token for Vault to use for token review
kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt

# Get the cluster CA certificate
kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt
```

### 3. Configure Vault Kubernetes Auth

```bash
# Set Vault address
export VAULT_ADDR=http://10.8.0.3:8200

# Login to Vault (if not already)
vault login

# Enable kubernetes auth (skip if already enabled)
vault auth enable kubernetes 2>/dev/null || echo "Kubernetes auth already enabled"

# Configure Vault to talk to Kubernetes
vault write auth/kubernetes/config \
  token_reviewer_jwt=@/tmp/token.jwt \
  kubernetes_host="https://10.8.40.49:6443" \
  kubernetes_ca_cert=@/tmp/ca.crt \
  disable_iss_validation=true

# Create the Vault role for external-secrets
vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names="vault-auth" \
  bound_service_account_namespaces="*" \
  policies="campground" \
  ttl=24h

# Clean up temporary files
rm /tmp/token.jwt /tmp/ca.crt
```

### 4. Verify Configuration

```bash
# Test that Vault can authenticate ServiceAccount tokens
TEST_TOKEN=$(kubectl -n external-secrets create token vault-auth --duration=10m)
vault write auth/kubernetes/login role=external-secrets jwt=$TEST_TOKEN

# Should return a Vault token - if you get "permission denied", see troubleshooting below
```

### 5. Trigger ClusterSecretStore Refresh

```bash
# Delete the ClusterSecretStore to force recreation
kubectl delete clustersecretstore vault-backend

# Wait for ArgoCD to recreate it (or manually apply)
sleep 5

# Verify it's ready
kubectl get clustersecretstore vault-backend
# Should show: vault-backend   Valid

# Check detailed status
kubectl describe clustersecretstore vault-backend
# Should show: Type: Ready, Status: True
```

## Troubleshooting

### Error: "permission denied" on vault login test

**Symptom:** When testing login, you get:
```
Error writing data to auth/kubernetes/login: Error making API request.
Code: 403. Errors:
* permission denied
```

**Cause:** The `vault-auth` ServiceAccount doesn't have the `system:auth-delegator` role.

**Fix:**
```bash
# Check if the ClusterRoleBinding exists
kubectl get clusterrolebinding vault-auth-delegator

# If not, create it
kubectl create clusterrolebinding vault-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=external-secrets:vault-auth

# Reconfigure Vault with a fresh token
kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt
vault write auth/kubernetes/config \
  token_reviewer_jwt=@/tmp/token.jwt \
  kubernetes_host="https://10.8.40.49:6443" \
  kubernetes_ca_cert=@/tmp/ca.crt \
  disable_iss_validation=true

rm /tmp/token.jwt

# Test again
TEST_TOKEN=$(kubectl -n external-secrets create token vault-auth --duration=10m)
vault write auth/kubernetes/login role=external-secrets jwt=$TEST_TOKEN
```

### ClusterSecretStore shows "InvalidProviderConfig"

**Symptom:**
```bash
kubectl describe clustersecretstore vault-backend
# Shows: Message: unable to log in to auth method: unable to log in with Kubernetes auth
```

**Debug Steps:**

1. **Verify Vault can reach Kubernetes API:**
```bash
# From vm-vault (or wherever Vault is running)
curl -k https://10.8.40.49:6443/version
# Should return JSON (401 Unauthorized is fine - means network is working)
```

2. **Check Vault configuration:**
```bash
vault read auth/kubernetes/config
# Verify kubernetes_host, token_reviewer_jwt_set: true
```

3. **Compare CA certificates:**
```bash
# Get what Vault has stored
vault read -field=kubernetes_ca_cert auth/kubernetes/config > /tmp/vault-ca.crt

# Get what Kubernetes actually uses
kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/k8s-ca.crt

# Compare them
diff /tmp/vault-ca.crt /tmp/k8s-ca.crt
# Should be identical - if different, reconfigure Vault
```

4. **Verify the Vault role exists:**
```bash
vault read auth/kubernetes/role/external-secrets
# Should show: bound_service_account_names: [vault-auth]
#              bound_service_account_namespaces: [*]
#              policies: [campground]
```

5. **Check the ClusterRoleBinding:**
```bash
kubectl get clusterrolebinding vault-auth-delegator -o yaml
# Should show:
#   subjects:
#   - kind: ServiceAccount
#     name: vault-auth
#     namespace: external-secrets
```

6. **Check external-secrets operator logs:**
```bash
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50
# Look for specific error messages about Vault authentication
```

### Token expired

**Symptom:** Everything was working, now ClusterSecretStore shows errors.

**Fix:** The `token_reviewer_jwt` in Vault has expired. Refresh it:
```bash
# Create a new token
kubectl -n external-secrets create token vault-auth --duration=24h > /tmp/token.jwt

# Update Vault config (keep other settings the same)
vault write auth/kubernetes/config \
  token_reviewer_jwt=@/tmp/token.jwt \
  kubernetes_host="https://10.8.40.49:6443" \
  kubernetes_ca_cert=@/tmp/ca.crt \
  disable_iss_validation=true

rm /tmp/token.jwt

# Restart ClusterSecretStore
kubectl delete clustersecretstore vault-backend
```

## GitOps Integration

The `vault-auth` ServiceAccount is managed by ArgoCD in the `vault-backend` Application. However, the ClusterRoleBinding must be created manually or added to your GitOps repo.

### Add ClusterRoleBinding to GitOps

Create `/config/packages/kubernetes-gitops/apps/external-secrets/vault-auth-clusterrolebinding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: external-secrets
```

This ensures the ClusterRoleBinding is automatically created when deploying the cluster.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Vault (vm-vault, 10.8.0.3)                                  │
│                                                             │
│  auth/kubernetes/config:                                    │
│    ├─ token_reviewer_jwt (from vault-auth SA)               │
│    ├─ kubernetes_host: https://10.8.40.49:6443             │
│    └─ kubernetes_ca_cert                                    │
│                                                             │
│  auth/kubernetes/role/external-secrets:                     │
│    ├─ bound_service_account_names: [vault-auth]            │
│    ├─ bound_service_account_namespaces: [*]                │
│    └─ policies: [campground]                                │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ (1) Token Review API calls
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes API (10.8.40.49:6443)                            │
│                                                             │
│  Validates JWT tokens using token review API               │
│  Requires caller to have system:auth-delegator role        │
└─────────────────────────────────────────────────────────────┘
                          ↑
                          │ (2) Token authentication
                          │
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster                                          │
│                                                             │
│  external-secrets namespace:                                │
│    ├─ ServiceAccount: vault-auth                           │
│    └─ ClusterSecretStore: vault-backend                    │
│         └─ Uses vault-auth to authenticate                 │
│                                                             │
│  ClusterRoleBinding: vault-auth-delegator                   │
│    └─ Grants system:auth-delegator to vault-auth           │
└─────────────────────────────────────────────────────────────┘
```

## How It Works

1. **External Secrets Operator** creates a JWT token from the `vault-auth` ServiceAccount
2. **Operator sends** the JWT to Vault's `/v1/auth/kubernetes/login` endpoint
3. **Vault receives** the JWT and needs to verify it with Kubernetes
4. **Vault calls** the Kubernetes Token Review API at `https://10.8.40.49:6443`
5. **Vault authenticates** to K8s using the `token_reviewer_jwt` (from the `vault-auth` SA)
6. **K8s checks** if the token_reviewer has `system:auth-delegator` permissions (ClusterRoleBinding)
7. **K8s validates** the original JWT and returns the result to Vault
8. **Vault grants** a Vault token to External Secrets Operator if validation succeeds
9. **Operator uses** the Vault token to read secrets from `secret/campground/*`

## References

- [Vault Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [External Secrets Operator](https://external-secrets.io/)
- [Kubernetes Token Review API](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#service-account-tokens)
