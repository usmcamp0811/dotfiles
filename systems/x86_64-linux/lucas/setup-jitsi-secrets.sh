#!/usr/bin/env bash
# Setup Jitsi Vault secrets for Lucas
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-https://vault.lan.aicampground.com}"
VAULT_PATH="secret/campground/jitsi"

echo "=== Jitsi Vault Secret Setup ==="
echo "Vault Address: $VAULT_ADDR"
echo "Vault Path: $VAULT_PATH"
echo ""

# Check if vault is accessible
if ! vault status &>/dev/null; then
    echo "Error: Cannot connect to Vault at $VAULT_ADDR"
    echo "Please ensure:"
    echo "  1. Vault is running"
    echo "  2. VAULT_ADDR is set correctly"
    echo "  3. You are authenticated (run 'vault login')"
    exit 1
fi

# Generate secrets
echo "Generating secrets..."
TURN_SECRET=$(openssl rand -hex 32)
VIDEOBRIDGE_SECRET=$(openssl rand -hex 32)

echo "Generated secrets:"
echo "  TURN_SECRET: ${TURN_SECRET:0:16}... (64 chars)"
echo "  VIDEOBRIDGE_SECRET: ${VIDEOBRIDGE_SECRET:0:16}... (64 chars)"
echo ""

# Store in Vault (KV v2)
echo "Storing secrets in Vault at $VAULT_PATH..."
vault kv put "$VAULT_PATH" \
  TURN_SECRET="$TURN_SECRET" \
  VIDEOBRIDGE_SECRET="$VIDEOBRIDGE_SECRET"

echo ""
echo "✓ Secrets successfully stored in Vault!"
echo ""
echo "Verification:"
vault kv get "$VAULT_PATH"

echo ""
echo "=== Next Steps ==="
echo "1. Ensure DNS is configured: meet.aicampground.com -> Lucas IP"
echo "2. Deploy NixOS configuration: sudo nixos-rebuild switch"
echo "3. Verify services are running:"
echo "   systemctl status jitsi-videobridge2"
echo "   systemctl status jicofo"
echo "   systemctl status prosody"
echo "   systemctl status coturn"
echo "   systemctl status vault-agent@jitsi-secrets"
echo "4. Check firewall allows ports: 80, 443, 3478, 10000, 49152-49252"
echo "5. Access Jitsi at: https://meet.aicampground.com"
