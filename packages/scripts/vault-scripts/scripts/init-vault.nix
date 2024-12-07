{ pkgs, }:
pkgs.writeShellScriptBin "init-vault" ''
  # Exit on any error
  set -e

  show_help() {
    cat <<EOF
  $(tput bold)$(tput setaf 3)init-vault:$(tput sgr0) Initialize and unseal a HashiCorp Vault server.

  $(tput bold)$(tput setaf 3)Usage:$(tput sgr0)
    $(tput setaf 2)init-vault [$(tput setaf 4)--key-file <path>$(tput sgr0)] [$(tput setaf 4)--token-file <path>$(tput sgr0)] [$(tput setaf 4)--help$(tput sgr0)]

  $(tput bold)$(tput setaf 3)Description:$(tput sgr0)
    $(tput setaf 6)- Initializes a HashiCorp Vault server with one unseal key and one root token.$(tput sgr0)
    $(tput setaf 6)- Saves the unseal key and root token to specified files or defaults.$(tput sgr0)
    $(tput setaf 6)- Automatically unseals the Vault after initialization.$(tput sgr0)

  $(tput bold)$(tput setaf 3)Options:$(tput sgr0)
    $(tput setaf 4)--key-file <path>$(tput sgr0)    Specify the path to save the unseal key. Default: $(tput bold)/var/lib/vault/unseal-key$(tput sgr0)
    $(tput setaf 4)--token-file <path>$(tput sgr0)  Specify the path to save the root token. Default: $(tput bold)/var/lib/vault/root-token$(tput sgr0)
    $(tput setaf 4)--help$(tput sgr0)               Show this help message and exit.
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
