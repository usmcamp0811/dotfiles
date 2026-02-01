# ArgoCD with Authentik OIDC Integration

This directory contains the configuration for ArgoCD with Authentik OIDC authentication.

## Components

- `values.yaml` - Helm chart values for ArgoCD including OIDC configuration
- `externalsecrets/` - ExternalSecret manifests to sync OIDC credentials from Vault

## Prerequisites

### Vault Kubernetes Authentication

**CRITICAL**: Before any ExternalSecrets will work (including the ArgoCD OIDC secret), you must configure Vault's Kubernetes authentication backend. This is a **one-time manual process** because Vault runs outside the cluster.

See `/config/modules/nixos/services/k3s/README.md` section "One-Time Vault Kubernetes Auth Setup" for the complete procedure.

**Quick setup (from a control plane node):**
```bash
# Set required environment variables
export VAULT_ADDR=http://10.8.0.3:8200
export VAULT_KV_PATH=secret/campground
export VAULT_KV_VERSION=v2
export VAULT_POLICY=campground
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export HOSTNAME=vm-k8s-control-0

# Run the setup script
nix run /config#vault-k8s-init.script
```

**Quick verification that Vault K8s auth is configured:**
```bash
vault read auth/kubernetes/config
vault read auth/kubernetes/role/external-secrets
kubectl get clustersecretstore vault-backend
```

If these commands fail, the ExternalSecret for ArgoCD OIDC will not sync.

## Vault Secret Structure

The ArgoCD Authentik OIDC integration requires the following secrets in Vault at `secret/campground/argocd`:

```json
{
  "OIDC_CLIENT_ID": "argocd-client-id-from-authentik",
  "OIDC_CLIENT_SECRET": "argocd-client-secret-from-authentik"
}
```

### Creating Vault Secrets

```bash
# Login to Vault
export VAULT_ADDR="http://10.8.0.3:8200"
vault login

# Write the secrets (replace with actual values from Authentik)
vault kv put secret/campground/k3s/argocd \
  OIDC_CLIENT_ID="your-client-id-here" \
  OIDC_CLIENT_SECRET="your-client-secret-here"
```

## Authentik Configuration

### 1. Create OAuth2/OIDC Provider in Authentik

1. Navigate to Authentik Admin UI: https://auth.aicampground.com
2. Go to **Applications** → **Providers** → **Create**
3. Select **OAuth2/OpenID Provider**
4. Configure the provider:
   - **Name**: `ArgoCD`
   - **Authentication flow**: `default-authentication-flow` (or your preferred flow)
   - **Authorization flow**: `default-provider-authorization-implicit-consent`
   - **Client type**: `Confidential`
   - **Client ID**: Generate or use custom (save this for Vault)
   - **Client Secret**: Generate (save this for Vault)
   - **Redirect URIs**:
     ```
     https://argocd.k8s.aicampground.com/auth/callback
     https://argocd.k8s.aicampground.com/api/dex/callback
     ```
   - **Signing Key**: Select your certificate
   - **Scopes**: `openid`, `profile`, `email`, `groups`
   - **Subject mode**: `Based on the User's hashed ID`
   - **Include claims in id_token**: `true`

5. Click **Create**

### 2. Create Application in Authentik

1. Go to **Applications** → **Applications** → **Create**
2. Configure:
   - **Name**: `ArgoCD`
   - **Slug**: `argocd`
   - **Provider**: Select the provider created above
   - **Launch URL**: `https://argocd.k8s.aicampground.com`
   - **Icon**: Optional (upload ArgoCD logo)

3. Click **Create**

### 3. Create Groups for RBAC

Create groups in Authentik for role-based access control:

1. Go to **Directory** → **Groups** → **Create**
2. Create two groups:
   - **ArgoCD Admins**: Full admin access to ArgoCD
   - **ArgoCD Viewers**: Read-only access to ArgoCD

3. Add users to the appropriate groups

### 4. Configure Property Mappings (if needed)

Ensure that the `groups` claim is included in the OIDC token:

1. Go to **Customization** → **Property Mappings**
2. Find or create an OIDC scope mapping for `groups`:
   - **Name**: `OpenID Groups`
   - **Scope name**: `groups`
   - **Expression**:
     ```python
     return {
         "groups": [group.name for group in request.user.ak_groups.all()]
     }
     ```
3. Ensure this mapping is selected in your ArgoCD provider's scopes

## RBAC Configuration

The ArgoCD RBAC policy is configured in `values.yaml`:

- Users in the **ArgoCD Admins** group get `role:admin`
- Users in the **ArgoCD Viewers** group get `role:readonly`
- Default policy for authenticated users: `role:readonly`

To customize RBAC, edit the `configs.rbac.policy.csv` section in `values.yaml`.

## Testing the Integration

1. Ensure the Vault secrets are created
2. Apply the ArgoCD configuration (handled by ArgoCD self-management)
3. Navigate to https://argocd.k8s.aicampground.com
4. Click "LOG IN VIA AUTHENTIK"
5. You should be redirected to Authentik for authentication
6. After successful login, you'll be redirected back to ArgoCD

## Troubleshooting

### OIDC Login Not Working

1. Check that the ExternalSecret has synced:
   ```bash
   kubectl get externalsecret -n argocd argocd-authentik-oidc
   kubectl get secret -n argocd argocd-authentik-oidc
   ```

2. Check ArgoCD server logs:
   ```bash
   kubectl logs -n argocd deployment/argocd-server
   ```

3. Verify the OIDC configuration:
   ```bash
   kubectl get configmap -n argocd argocd-cm -o yaml
   ```

### Invalid Redirect URI

Ensure the redirect URIs in Authentik match exactly:
- `https://argocd.k8s.aicampground.com/auth/callback`
- `https://argocd.k8s.aicampground.com/api/dex/callback`

### Groups Not Showing in ArgoCD

1. Verify the groups claim is included in the ID token from Authentik
2. Check that users are members of the correct Authentik groups
3. Verify the property mapping for groups is configured and assigned to the provider

## References

- [ArgoCD OIDC Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#existing-oidc-provider)
- [Authentik OAuth2 Provider](https://docs.goauthentik.io/docs/providers/oauth2/)
- [ArgoCD RBAC](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
