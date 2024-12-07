{ pkgs }:
pkgs.writeShellScriptBin "save-approle-secrets" ''
    # Function to display help
    show_help() {
      cat <<EOF
  Usage: save-approle-secrets <approle_name>

  This script retrieves the role ID and secret ID for a specified AppRole in HashiCorp Vault
  and saves them securely to /var/lib/vault/<approle_name>.

  Options:
    <approle_name>  The name of the AppRole whose secrets are to be retrieved (required).

  Behavior:
    - Checks if the specified AppRole exists in Vault.
    - Prompts for Vault login if not already authenticated.
    - Retrieves the AppRole's role ID and secret ID.
    - Saves the credentials to the following files:
        - /var/lib/vault/<approle_name>/role-id
        - /var/lib/vault/<approle_name>/secret-id
    - Ensures the credentials are saved with secure file permissions.

  Examples:
    save-approle-secrets my-approle

  Notes:
    - You must have appropriate permissions in Vault to access the AppRole and its secrets.
    - The target directory (/var/lib/vault/<approle_name>) will be created if it does not exist.

  EOF
    }

    # Check if --help or -h is passed
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
      show_help
      exit 0
    fi

    set -e

    # Check that an AppRole name was provided
    if [ -z "$1" ]; then
      echo "Error: AppRole name not provided. Use --help for usage information."
      exit 1
    fi

    # Set the AppRole name
    approle_name=$1

    # Verify if the AppRole exists in Vault
    if ${pkgs.vault-bin}/bin/vault read auth/approle/role/$approle_name > /dev/null 2>&1; then
      echo "AppRole $approle_name exists."
    else
      echo "AppRole $approle_name does not exist."
      echo "Please run 'create-approle "$approle_name"' to create it."
      exit 1
    fi

    # Check if already logged into Vault
    vault_status=$(${pkgs.vault-bin}/bin/vault status -format=json 2>/dev/null)

    if [ $? -eq 0 ]; then
      echo "Already logged into Vault."
    else
      echo "Please log in to Vault..."
      ${pkgs.vault-bin}/bin/vault login || { echo "Vault login failed."; exit 1; }
    fi

    # Verify that login was successful
    if [ $? -ne 0 ]; then
      echo "Vault login failed."
      exit 1
    fi

    # Ensure the target directory exists with correct permissions
    sudo mkdir -p /var/lib/vault/$approle_name
    sudo chmod -R 777 /var/lib/vault/$approle_name

    # Retrieve and save the role ID
    role_id=$(${pkgs.vault-bin}/bin/vault read -field=role_id auth/approle/role/$approle_name/role-id)
    echo $role_id | sudo tee /var/lib/vault/$approle_name/role-id > /dev/null

    # Retrieve and save the secret ID
    secret_id=$(${pkgs.vault-bin}/bin/vault write -f -field=secret_id auth/approle/role/$approle_name/secret-id)
    echo $secret_id | sudo tee /var/lib/vault/$approle_name/secret-id > /dev/null

    # Secure the saved credentials
    sudo chmod -R 0400 /var/lib/vault/$approle_name

    echo "AppRole credentials saved to /var/lib/vault/$approle_name/role-id and /var/lib/vault/$approle_name/secret-id."
''
