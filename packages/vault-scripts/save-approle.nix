{
  pkgs,
  new-approle,
}:
pkgs.writeShellScriptBin "save-approle-secrets" ''
  set -e
  # Check that an approle name was provided
  if [ -z "$1" ]; then
    echo "Usage: save-approle-secrets <approle_name>"
    exit 1
  fi

  # Set the approle name
  approle_name=$1

  if ${pkgs.vault}/bin/vault read auth/approle/role/$approle_name > /dev/null 2>&1; then
      echo "Approle $approle_name exists."
  else
      echo "Approle $approle_name does not exist."
      echo "Please run 'create-approle "$approle_name"'"
      exit 1
  fi

  # Check if already logged into Vault
  vault_status=$(${pkgs.vault}/bin/vault status -format=json 2>/dev/null)

  if [ $? -eq 0 ]; then
    echo "Already logged into Vault."
  else
    echo "Please login to Vault..."
    ${pkgs.vault}/bin/vault login || { echo "Vault login failed."; exit 1; }
  fi

  # Check that login was successful
  if [ $? -ne 0 ]; then
    echo "Vault login failed."
    exit 1
  fi

  sudo mkdir -p /var/lib/vault/$approle_name
  sudo chmod -R 777 /var/lib/vault/$approle_name

  # Retrieve and save the role-id
  role_id=$(${pkgs.vault}/bin/vault read -field=role_id auth/approle/role/$approle_name/role-id)
  echo $role_id | sudo tee /var/lib/vault/$approle_name/role-id > /dev/null

  # Retrieve and save the secret-id
  secret_id=$(${pkgs.vault}/bin/vault write -f -field=secret_id auth/approle/role/$approle_name/secret-id)
  echo $secret_id | sudo tee /var/lib/vault/$approle_name/secret-id > /dev/null

  sudo chmod -R 0400 /var/lib/vault/$approle_name
  echo "AppRole credentials saved to /var/lib/vault/$approle_name/role-id and /var/lib/vault/$approle_name/secret-id."
''
