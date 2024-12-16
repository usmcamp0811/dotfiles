{ pkgs, ... }:
pkgs.writeShellScriptBin "vault-crawler" ''

  # Colors for output
  RED="\\033[0;31m"
  GREEN="\\033[0;32m"
  BLUE="\\033[0;34m"
  YELLOW="\\033[1;33m"
  NC="\\033[0m" # No Color

  # Function to display help
  show_help() {
      echo -e "''${BLUE}Vault Crawler''${NC}"
      echo -e "''${GREEN}Description:''${NC} This script recursively crawls a Vault path and generates commands to recreate secrets."
      echo -e "''${GREEN}Usage:''${NC}"
      echo -e "  ''${YELLOW}vault-crawler <base_path>''${NC}"
      echo -e "''${GREEN}Options:''${NC}"
      echo -e "  ''${YELLOW}--help''${NC}     Show this help message."
      echo -e "''${GREEN}Examples:''${NC}"
      echo -e "  ''${YELLOW}vault-crawler secret/campground/''${NC}"
      echo -e "  ''${YELLOW}vault-crawler secret/application/''${NC}"
      exit 0
  }

  # Check for --help flag
  if [[ "$1" == "--help" ]]; then
      show_help
  fi

  # Ensure Vault CLI is authenticated and ready
  if ! ${pkgs.vault-bin}/bin/vault status >/dev/null 2>&1; then
      echo -e "''${RED}Vault CLI is not authenticated or configured properly.''${NC}"
      exit 1
  fi

  # Validate input
  if [ $# -ne 1 ]; then
      echo -e "''${RED}Usage: 'vault-crawler' <base_path>''${NC}"
      echo -e "Run $YELLOW'vault-crawler --help' ''${NC} for more information."
      exit 1
  fi

  BASE_PATH=$1
  ENV_VARS=""
  KV_COMMANDS=""

  # Function to recursively list keys and generate commands
  generate_kv_put_commands() {
      local path=$1

      # List keys at the current path
      keys=$(${pkgs.vault-bin}/bin/vault kv list -format=json "$path" 2>/dev/null | jq -r '.[]')

      for key in $keys; do
          # Check if it's a folder (ends with '/')
          if [[ $key == */ ]]; then
              # Recurse into the folder
              generate_kv_put_commands "''${path}''${key}"
          else
              # Properly concatenate path and key
              full_path="''${path%/}/$key"
              # Read the secret and generate a `${pkgs.vault-bin}/bin/vault kv put` command
              secret=$(${pkgs.vault-bin}/bin/vault kv get -format=json "$full_path" 2>/dev/null)
              if [ $? -eq 0 ]; then
                  # Extract key names from the JSON
                  data_keys=$(echo "$secret" | jq -r '.data.data | keys[]')
                  kv_command="vault kv put $full_path"
                  for data_key in $data_keys; do
                      unique_env_var_name=$(echo "''${full_path}_''${data_key}" | tr '[:lower:]' '[:upper:]' | tr '/' '_')
                      ENV_VARS+="export $unique_env_var_name='placeholder text'\n"
                      kv_command+=" $data_key=\"\''${$unique_env_var_name}\""
                  done
                  KV_COMMANDS+="$kv_command\n"
              else
                  echo -e "''${RED}Error reading secret: $full_path''${NC}" >&2
              fi
          fi
      done
  }

  echo -e "''${BLUE}Starting Vault Crawler for path: ''${YELLOW}$BASE_PATH''${NC}"
  # Start the recursion
  generate_kv_put_commands "$BASE_PATH"

  # Print environment variables and commands
  echo -e "''${GREEN}Export the following environment variables:''${NC}"
  echo -e "$ENV_VARS"
  echo -e "''${GREEN}Vault KV Put Commands:''${NC}"
  echo -e "$KV_COMMANDS"

  echo -e "''${GREEN}Vault Crawler completed.''${NC}"
''
