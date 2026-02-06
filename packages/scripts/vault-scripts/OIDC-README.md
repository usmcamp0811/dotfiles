# Configuring Vault with Authentik as an OIDC Provider

This guide walks you through configuring HashiCorp Vault to use Authentik as its OIDC (OpenID Connect) provider.

---

## Prerequisites

- A running instance of HashiCorp Vault with UI enabled.
- Authentik deployed and accessible.
- An OIDC application created in Authentik for Vault.

### Authentik Setup

1. **Create an Application in Authentik:**

   - Navigate to **Applications** and create a new application for Vault.
   - Set the **Redirect URIs** as follows:
     - `https://vault.lan.aicampground.com/ui/vault/auth/oidc/oidc/callback`
     - `https://vault.lan.aicampground.com/oidc/callback`
     - `http://localhost:8250/oidc/callback`
   - Note down the **Client ID** and **Client Secret**.

2. **Assign Users to the Application:**
   - Ensure the appropriate users/groups are assigned to the Vault application in Authentik.

---

## Configuring Vault

### Step 1: Enable the OIDC Authentication Method

```sh
vault auth enable oidc
```

### Step 2: Configure the OIDC Provider

Run the following command, replacing placeholders with values from your Authentik application:

```sh
vault write auth/oidc/config \
  oidc_discovery_url="https://authentik.lan.aicampground.com/application/o/vault/" \
  oidc_client_id="<COPY FROM AUTHENTIK>" \
  oidc_client_secret="<COPY FROM AUTHENTIK>" \
  default_role="reader"
```

### Step 3: Define a Role in Vault

Define a role that maps users from Authentik to Vault policies. Replace `<YOUR CLIENT ID FROM ABOVE>` with your Authentik Client ID.

```sh
vault write auth/oidc/role/reader \
  bound_audiences="<YOUR CLIENT ID FROM ABOVE>" \
  allowed_redirect_uris="https://vault.lan.aicampground.com/ui/vault/auth/oidc/oidc/callback" \
  allowed_redirect_uris="https://vault.lan.aicampground.com/oidc/callback" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  user_claim="sub" \
  policies="campground"
```

---

## Notes

- **Redirect URIs:** Ensure the redirect URIs configured in Vault match exactly with those set in the Authentik application.
- **OIDC Discovery URL:** This URL should point to the specific OIDC application endpoint in Authentik.
- **Testing:** After configuration, navigate to the Vault login page, select the OIDC method, and authenticate via Authentik.

---

## Troubleshooting

- **OIDC Login Fails:**
  - Verify the `oidc_discovery_url` is correct and accessible.
  - Check the redirect URIs in both Vault and Authentik for typos.
- **Access Denied:**
  - Ensure the assigned Authentik users/groups have appropriate roles.
  - Verify the Vault policies assigned to the role (e.g., `campground`) match the expected permissions.
