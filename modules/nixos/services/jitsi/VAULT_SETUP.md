# Vault Setup for Jitsi Meet

This guide explains how to configure HashiCorp Vault for use with the Jitsi Meet module.

## Prerequisites

- HashiCorp Vault instance (e.g., `vault.aicampground.com:8200`)
- Vault AppRole authentication configured
- Vault Agent configured on the NixOS host (via `fmf.services.vault-agent`)

## Required Secrets

The Jitsi module requires three secrets to be stored in Vault:

### 1. TURN_SECRET
Used by the Coturn TURN server for authentication between clients and the TURN server.

**Generation:**
```bash
openssl rand -hex 32
```

### 2. COMPONENT_SECRET
Used for XMPP component authentication between Jitsi Meet components (Prosody, Jicofo, Videobridge).

**Generation:**
```bash
openssl rand -hex 32
```

### 3. VIDEOBRIDGE_SECRET
Used by Jitsi Videobridge to authenticate with Jicofo.

**Generation:**
```bash
openssl rand -hex 32
```

## Vault Configuration

### Option 1: Vault KV Version 2 (Recommended)

Store secrets in a KV v2 secret engine:

```bash
# Generate secrets
TURN_SECRET=$(openssl rand -hex 32)
COMPONENT_SECRET=$(openssl rand -hex 32)
VIDEOBRIDGE_SECRET=$(openssl rand -hex 32)

# Store in Vault (KV v2)
vault kv put secret/campground/jitsi \
  TURN_SECRET="${TURN_SECRET}" \
  COMPONENT_SECRET="${COMPONENT_SECRET}" \
  VIDEOBRIDGE_SECRET="${VIDEOBRIDGE_SECRET}"
```

**NixOS Configuration:**
```nix
{
  fmf.services.jitsi = {
    enable = true;
    vault = {
      enable = true;
      vault-path = "secret/campground/jitsi";
      kvVersion = "v2";  # This is the default
    };
  };
}
```

### Option 2: Vault KV Version 1

Store secrets in a KV v1 secret engine:

```bash
# Generate secrets
TURN_SECRET=$(openssl rand -hex 32)
COMPONENT_SECRET=$(openssl rand -hex 32)
VIDEOBRIDGE_SECRET=$(openssl rand -hex 32)

# Store in Vault (KV v1)
vault write secret/campground/jitsi \
  TURN_SECRET="${TURN_SECRET}" \
  COMPONENT_SECRET="${COMPONENT_SECRET}" \
  VIDEOBRIDGE_SECRET="${VIDEOBRIDGE_SECRET}"
```

**NixOS Configuration:**
```nix
{
  fmf.services.jitsi = {
    enable = true;
    vault = {
      enable = true;
      vault-path = "secret/campground/jitsi";
      kvVersion = "v1";
    };
  };
}
```

## Vault Policies

Create a policy for the Jitsi AppRole to access the secrets:

```hcl
# jitsi-policy.hcl
path "secret/data/campground/jitsi" {
  capabilities = ["read"]
}

# For KV v1, use:
# path "secret/campground/jitsi" {
#   capabilities = ["read"]
# }
```

Apply the policy:
```bash
vault policy write jitsi jitsi-policy.hcl
```

## AppRole Configuration

If not already configured, create an AppRole for the Jitsi host:

```bash
# Enable AppRole auth method (if not already enabled)
vault auth enable approle

# Create the AppRole
vault write auth/approle/role/jitsi \
  token_policies="jitsi" \
  token_ttl=1h \
  token_max_ttl=4h

# Get the role-id
vault read auth/approle/role/jitsi/role-id

# Generate a secret-id
vault write -f auth/approle/role/jitsi/secret-id
```

Store the `role-id` and `secret-id` on the NixOS host where Vault Agent can read them.

## Vault Agent Configuration

The Jitsi module automatically configures Vault Agent to retrieve secrets. Ensure your global Vault Agent settings are configured:

```nix
{
  fmf.services.vault-agent = {
    enable = true;
    settings = {
      vault = {
        address = "https://vault.aicampground.com:8200";
        role-id = "/etc/vault/role-id";
        secret-id = "/etc/vault/secret-id";
      };
    };
  };
}
```

## Verifying Secrets Retrieval

After deploying, verify that Vault Agent successfully retrieved the secrets:

```bash
# Check Vault Agent service status
systemctl status vault-agent@jitsi-secrets

# Check logs
journalctl -u vault-agent@jitsi-secrets -f

# Verify secrets files exist
ls -la /tmp/detsys-vault/

# Check permissions (should be 0600)
stat /tmp/detsys-vault/jitsi-turn-secret
stat /tmp/detsys-vault/jitsi-component-secret
stat /tmp/detsys-vault/videobridge-secret
```

## Secret Rotation

To rotate secrets:

1. **Generate new secrets:**
   ```bash
   NEW_TURN_SECRET=$(openssl rand -hex 32)
   NEW_COMPONENT_SECRET=$(openssl rand -hex 32)
   NEW_VIDEOBRIDGE_SECRET=$(openssl rand -hex 32)
   ```

2. **Update Vault:**
   ```bash
   # KV v2
   vault kv put secret/campground/jitsi \
     TURN_SECRET="${NEW_TURN_SECRET}" \
     COMPONENT_SECRET="${NEW_COMPONENT_SECRET}" \
     VIDEOBRIDGE_SECRET="${NEW_VIDEOBRIDGE_SECRET}"
   
   # KV v1
   vault write secret/campground/jitsi \
     TURN_SECRET="${NEW_TURN_SECRET}" \
     COMPONENT_SECRET="${NEW_COMPONENT_SECRET}" \
     VIDEOBRIDGE_SECRET="${NEW_VIDEOBRIDGE_SECRET}"
   ```

3. **Restart services:**
   ```bash
   # Vault Agent will detect changes and restart Jitsi services
   systemctl restart vault-agent@jitsi-secrets
   
   # Or manually restart Jitsi services
   systemctl restart coturn
   systemctl restart jitsi-videobridge2
   systemctl restart jicofo
   systemctl restart prosody
   ```

## Troubleshooting

### Vault Agent Not Starting

**Check:**
1. Verify role-id and secret-id files exist and are readable
2. Check Vault address is correct and reachable
3. Verify AppRole is configured correctly

**Commands:**
```bash
# Test Vault connectivity
curl -k https://vault.aicampground.com:8200/v1/sys/health

# Verify AppRole authentication
vault write auth/approle/login \
  role_id="$(cat /etc/vault/role-id)" \
  secret_id="$(cat /etc/vault/secret-id)"
```

### Secrets Not Being Retrieved

**Check:**
1. Vault policy allows reading the secret path
2. Secret path in NixOS config matches Vault path
3. KV version matches (v1 vs v2)

**Commands:**
```bash
# Test reading secrets manually
vault kv get secret/campground/jitsi  # KV v2
vault read secret/campground/jitsi    # KV v1

# Check policy
vault policy read jitsi
```

### Permission Denied Errors

**Check:**
1. AppRole token has correct policies attached
2. Policy path matches the KV version:
   - KV v2: `secret/data/campground/jitsi`
   - KV v1: `secret/campground/jitsi`

### Services Not Restarting on Secret Change

**Check:**
1. Verify `change-action = "restart"` is set in vault-agent config (default)
2. Check Vault Agent logs for errors
3. Manually restart services if needed

## Security Best Practices

1. **Rotate secrets regularly** (e.g., every 90 days)
2. **Use AppRole with limited TTL** to reduce token lifetime
3. **Restrict Vault policies** to only the secrets needed
4. **Use Vault audit logging** to track secret access
5. **Secure role-id and secret-id files** with proper permissions (0600)
6. **Use Vault namespaces** for multi-tenant environments (if applicable)
7. **Enable Vault audit logs** to track secret access

## References

- [Vault AppRole Authentication](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Vault KV Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/kv)
- [Vault Agent](https://developer.hashicorp.com/vault/docs/agent)
- [DeterminateSystems Vault Service](https://github.com/DeterminateSystems/nixos-vault-service)
