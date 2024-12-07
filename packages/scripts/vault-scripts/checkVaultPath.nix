{ pkgs }:
pkgs.writeShellScriptBin "check-vault-path" ''
    # Function to display help
    show_help() {
      cat <<EOF
  Usage: check-vault-path <vault-path>

  This script checks the existence of a specific path in HashiCorp Vault. 

  It supports:
    - PKI engine paths (e.g., /issue/<role>)
    - Generic KV paths
    - Parent directories of Vault paths

  Options:
    <vault-path>  The full path in Vault to check (required).

  Examples:
    check-vault-path secret/data/my-secret
    check-vault-path pki/issue/my-role

  Return Codes:
    0 - The path exists or is accessible in Vault.
    1 - The path does not exist or access is denied.

  Notes:
    - You must be authenticated with Vault before running this script.
    - The script checks for both PKI engine paths and KV paths.

  EOF
    }

    # Check if --help or -h is passed
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
      show_help
      exit 0
    fi

    # Validate input
    if [ -z "$1" ]; then
      echo "Error: Vault path not provided. Use --help for usage information."
      exit 1
    fi

    full_path="$1"

    # Check for PKI engines
    if [[ "$full_path" == *"/issue/"* ]]; then
      engine_path=$(echo "$full_path" | awk -F '/issue/' '{print $1}')
      role=$(echo "$full_path" | awk -F '/issue/' '{print $2}')

      if vault read -format=json "$engine_path/roles/$role" > /dev/null 2>&1; then
        exit 0
      fi
    else
      # Try listing the parent path
      parent_path=$(dirname "$full_path")
      if [ "$parent_path" == "." ]; then
        parent_path=""
      fi

      output=$(vault list -format=json "$parent_path" 2>&1)
      if [[ "$output" == *"$full_path"* || "$output" == *"listing is not allowed"* ]]; then
        exit 0
      elif vault kv get $1 > /dev/null 2>&1; then
        exit 0
      elif vault kv list $1/ > /dev/null 2>&1; then
        exit 0
      fi
    fi

    exit 1
''
