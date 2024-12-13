{ pkgs, }:
pkgs.writeShellScriptBin "${pkgs.vault}/bin/vault-crawler" ''

  # Ensure Vault CLI is authenticated and ready
  if ! ${pkgs.vault}/bin/vault status >/dev/null 2>&1; then
      echo "Vault CLI is not authenticated or configured properly."
      exit 1
  fi

  # Validate input
  if [ $# -ne 1 ]; then
      echo "Usage: $0 <base_path>"
      exit 1
  fi

  BASE_PATH=$1

  # Function to recursively list keys and generate commands
  generate_kv_put_commands() {
      local path=$1

      # List keys at the current path
      keys=$(${pkgs.vault}/bin/vault kv list -format=json "$path" 2>/dev/null | jq -r '.[]')

      for key in $keys; do
          # Check if it's a folder (ends with '/')
          if [[ $key == */ ]]; then
              # Recurse into the folder
              generate_kv_put_commands "''${path}''${key}"
          else
              # Properly concatenate path and key
              full_path="''${path%/}/$key"
              # Read the secret and generate a `${pkgs.vault}/bin/vault kv put` command
              secret=$(${pkgs.vault}/bin/vault kv get -format=json "$full_path" 2>/dev/null)
              if [ $? -eq 0 ]; then
                  # Extract key names from the JSON
                  data_keys=$(echo "$secret" | jq -r '.data.data | keys[]')
                  command="vault kv put $full_path"
                  for data_key in $data_keys; do
                      command+=" $data_key={PLACEHOLDER}"
                  done
                  echo "$command"
              else
                  echo "Error reading secret: $full_path" >&2
              fi
          fi
      done
  }

  # Start the recursion
  generate_kv_put_commands "$BASE_PATH"
''
