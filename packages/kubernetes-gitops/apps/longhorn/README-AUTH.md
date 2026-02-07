# Longhorn OIDC Authentication Setup

Longhorn doesn't have native OIDC support, so we use **Traefik ForwardAuth with Authentik** to protect the Longhorn UI.

## Architecture

```
User → Traefik IngressRoute → ForwardAuth Middleware → Authentik Outpost → Longhorn UI
                                      ↓
                              Authentik checks auth
                                      ↓
                              Returns 200 + headers (authorized)
                              Returns 302 redirect (not authorized)
```

## Setup Steps

### 1. Create Authentik Proxy Provider

In your Authentik instance (https://auth.aicampground.com):

1. Go to **Applications** → **Providers** → **Create**
2. Select **Proxy Provider**
3. Configure:
   - **Name**: `Longhorn`
   - **Authorization flow**: Choose your default authorization flow (e.g., `default-provider-authorization-implicit-consent`)
   - **Type**: `Forward auth (single application)`
   - **External host**: `https://longhorn.k8s.aicampground.com`
   - **Mode**: `Forward auth (single application)`
   - Click **Finish**

### 2. Create Authentik Application

1. Go to **Applications** → **Applications** → **Create**
2. Configure:
   - **Name**: `Longhorn`
   - **Slug**: `longhorn`
   - **Provider**: Select the `Longhorn` provider you just created
   - **UI Settings** (optional):
     - **Launch URL**: `https://longhorn.k8s.aicampground.com`
     - **Icon**: Upload Longhorn logo or use URL
   - Click **Create**

### 3. Outpost Configuration

**Important**: Since Authentik runs as an external MicroVM (not in Kubernetes), we use the **embedded outpost** which runs on the Authentik server itself.

The ForwardAuth middleware points to:
```
https://auth.aicampground.com/outpost.goauthentik.io/auth/traefik
```

**You do NOT need to create a Kubernetes outpost** for this setup. The embedded outpost is automatically available on your Authentik instance.

#### Alternative: Proxy Outpost in Kubernetes (Advanced)

If you want to avoid external calls and keep auth checks internal to the cluster, you can:

1. In Authentik UI: Applications → Outposts → Create
2. Create a **Proxy** type outpost
3. Associate it with the Longhorn provider
4. Deploy it as a Kubernetes deployment that connects to Authentik
5. Update the middleware to point to the in-cluster outpost service

For most use cases, the embedded outpost is sufficient.

### 4. Deploy the Configuration

The GitOps setup includes:
- `middleware-auth.yaml` - Traefik ForwardAuth middleware pointing to Authentik
- `ingressroute.yaml` - IngressRoute with middleware applied

When ArgoCD syncs, these will be deployed automatically.

### 5. Test Authentication

1. Navigate to https://longhorn.k8s.aicampground.com
2. You should be redirected to Authentik for authentication
3. After logging in, you'll be redirected back to Longhorn UI

## Troubleshooting

### 401 Unauthorized

- Check that the Authentik outpost is running: `kubectl get pods -n authentik`
- Verify the ForwardAuth address is correct in `middleware-auth.yaml`
- Check Authentik provider configuration

### Redirect Loop

- Ensure the **External host** in the Authentik provider matches the IngressRoute hostname
- Verify the **Mode** is set to `Forward auth (single application)`

### 404 Not Found from Authentik

- The outpost endpoint might be wrong
- Check the Authentik version and adjust the path if needed
- Verify the outpost is associated with the Longhorn provider

## References

- [Authentik Traefik Integration](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_traefik/)
- [Traefik ForwardAuth Middleware](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [Longhorn Access UI Documentation](https://longhorn.io/docs/1.10.0/deploy/accessing-the-ui/)
