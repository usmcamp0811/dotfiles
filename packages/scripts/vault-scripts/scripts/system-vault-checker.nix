{ pkgs, checkVaultPath, }:
let flake-src = ../../../../.;
in pkgs.writeShellScriptBin "get-vault-paths" ''
  # Define colors for output
  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  RESET="\033[0m"

  # Function to display help
  show_help() {
    echo -e "${YELLOW}Usage:${RESET}"
    echo -e "  vault-checker.sh [options]"
    echo
    echo -e "${YELLOW}Options:${RESET}"
    echo -e "  -t, --template <file>   Specify the Vault-client template file to process."
    echo -e "  -j, --json              Output results in JSON format."
    echo -e "  -h, --help              Show this help message."
  }

  # Parse arguments
  TEMPLATE_FILE=""
  JSON_OUTPUT=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--template) TEMPLATE_FILE="$2"; shift 2;;
      -j|--json) JSON_OUTPUT=1; shift;;
      -h|--help) show_help; exit 0;;
      *) echo -e "${RED}Unknown argument: $1${RESET}"; show_help; exit 1;;
    esac
  done

  # Check for required arguments
  if [[ -z "$TEMPLATE_FILE" ]]; then
    echo -e "${RED}Error: Template file is required.${RESET}"
    show_help
    exit 1
  fi

  # Check if template file exists
  if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo -e "${RED}Error: Template file not found at '$TEMPLATE_FILE'.${RESET}"
    exit 1
  fi

  # Use Nix function to extract Vault path and fields
  RESULT=$(nix eval --raw --impure --expr "
    let
      extractVaultPathAndFields = ${extractVaultPathAndFields};
      template = builtins.readFile \"$TEMPLATE_FILE\";
    in
      builtins.toJSON (extractVaultPathAndFields template)
  ")

  # Parse the JSON result
  VAULT_PATH=$(echo "$RESULT" | jq -r '.path')
  FIELDS=$(echo "$RESULT" | jq -c '.fields')

  # Check if path is empty
  if [[ -z "$VAULT_PATH" ]]; then
    echo -e "${RED}Error: No Vault path found in the template.${RESET}"
    exit 1
  fi

  # Initialize output JSON
  OUTPUT_JSON="{\"path\": \"$VAULT_PATH\", \"fields\": {}}"

  # Check Vault for each field
  ERROR_FOUND=0
  for FIELD in $(echo "$FIELDS" | jq -r '.[]'); do
    # Check if field exists in Vault
    if vault kv get -field="$FIELD" "$VAULT_PATH" &>/dev/null; then
      if [[ $JSON_OUTPUT -eq 0 ]]; then
        echo -e "${GREEN}✓ Field exists: $FIELD${RESET}"
      fi
      OUTPUT_JSON=$(echo "$OUTPUT_JSON" | jq --arg field "$FIELD" '.fields[$field] = true')
    else
      ERROR_FOUND=1
      if [[ $JSON_OUTPUT -eq 0 ]]; then
        echo -e "${RED}✗ Field does not exist: $FIELD${RESET}"
      fi
      OUTPUT_JSON=$(echo "$OUTPUT_JSON" | jq --arg field "$FIELD" '.fields[$field] = false')
    fi
  done

  # Output results in JSON format if requested
  if [[ $JSON_OUTPUT -eq 1 ]]; then
    echo "$OUTPUT_JSON" | jq
  fi

  # Exit with error code if any field was missing
  if [[ $ERROR_FOUND -eq 1 ]]; then
    exit 1
  else
    exit 0
  fi
''
