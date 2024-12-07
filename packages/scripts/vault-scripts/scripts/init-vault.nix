{ pkgs, }:
pkgs.writeShellScriptBin "init-vault" ''
  # Exit on any error
  set -e

  # Define where to save the keys and token securely
  KEY_FILE="/var/lib/vault/unseal-key"
  TOKEN_FILE="/var/lib/vault/root-token"

  # Ensure the directory exists with correct permissions
  ${pkgs.sudo}/bin/sudo mkdir -p /var/lib/${pkgs.vault-bin}/bin/vault
  ${pkgs.sudo}/bin/sudo chmod 700 /var/lib/${pkgs.vault-bin}/bin/vault

  # Check if Vault is already initialized
  if ${pkgs.vault-bin}/bin/vault status | grep -q "Initialized.*true"; then
    echo "Vault is already initialized."
    exit 0
  fi

  # Initialize Vault with a single key
  init_output=$(${pkgs.vault-bin}/bin/vault operator init -key-shares=1 -key-threshold=1 -format=json)

  # Extract the unseal key and root token
  unseal_key=$(echo "$init_output" | ${pkgs.jq}/bin/jq -r ".unseal_keys_b64[0]")
  root_token=$(echo "$init_output" | ${pkgs.jq}/bin/jq -r ".root_token")

  # Save the unseal key and root token securely
  echo "$unseal_key" | ${pkgs.sudo}/bin/sudo tee "$KEY_FILE" > /dev/null
  echo "$root_token" | ${pkgs.sudo}/bin/sudo tee "$TOKEN_FILE" > /dev/null
  ${pkgs.sudo}/bin/sudo chmod 600 "$KEY_FILE" "$TOKEN_FILE"

  # Unseal Vault
  ${pkgs.vault-bin}/bin/vault operator unseal "$unseal_key"

  # Output success message
  echo "Vault initialized and unsealed successfully."
  echo "Unseal key saved to $KEY_FILE"
  echo "Root token saved to $TOKEN_FILE"
''
