{ pkgs, }:
pkgs.writeShellScriptBin "init-vault" ''
    # Exit on any error
    set -e

    show_help() {
      ${pkgs.bat}/bin/bat -p -l markdown <<'EOF'
  init-vault: Initialize and unseal a HashiCorp Vault server.
  Usage:
    init-vault [--key-file <path>] [--token-file <path>] [--help]

  Description:
    - Initializes a HashiCorp Vault server with one unseal key and one root token.
    - Saves the unseal key and root token to specified files or defaults.
    - Automatically unseals the Vault after initialization.

  Options:
    --key-file <path>    Specify the path to save the unseal key. Default: /var/lib/vault/unseal-key
    --token-file <path>  Specify the path to save the root token. Default: /var/lib/vault/root-token
    --help               Show this help message and exit.
  EOF
    }

    # Default file locations
    KEY_FILE="/var/lib/vault/unseal-key"
    TOKEN_FILE="/var/lib/vault/root-token"

    # Parse arguments
    while [ $# -gt 0 ]; do
      case "$1" in
        --key-file)
          KEY_FILE="$2"
          shift 2
          ;;
        --token-file)
          TOKEN_FILE="$2"
          shift 2
          ;;
        --help)
          show_help
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          show_help
          exit 1
          ;;
      esac
    done

    # Ensure the directories for the files exist
    mkdir -p "$(dirname "$KEY_FILE")"
    mkdir -p "$(dirname "$TOKEN_FILE")"

    # Check write permissions for the files
    if ! touch "$KEY_FILE" 2>/dev/null; then
      echo "Error: Cannot write to $KEY_FILE. Ensure the directory is writable."
      exit 1
    fi
    if ! touch "$TOKEN_FILE" 2>/dev/null; then
      echo "Error: Cannot write to $TOKEN_FILE. Ensure the directory is writable."
      exit 1
    fi

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
    echo "$unseal_key" > "$KEY_FILE"
    echo "$root_token" > "$TOKEN_FILE"
    chmod 600 "$KEY_FILE" "$TOKEN_FILE"

    # Unseal Vault
    ${pkgs.vault-bin}/bin/vault operator unseal "$unseal_key"

    # Output success message
    echo "Vault initialized and unsealed successfully."
    echo "Unseal key saved to $KEY_FILE"
    echo "Root token saved to $TOKEN_FILE"
''
