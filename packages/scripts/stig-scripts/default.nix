{ pkgs, lib }:
let flake-src = ../../../../.;
in pkgs.writeShellScriptBin "system-stig-check" ''
  # Define colors for output
  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  RESET="\033[0m"

  # Function to display help
  show_help() {
    echo -e "''${YELLOW}Usage:''${RESET}"
    echo -e "  system-check <system-name> [--json]"
    echo
    echo -e "''${YELLOW}Options:''${RESET}"
    echo -e "  -h, --help          Show this help message."
    echo -e "  --json              Output in JSON format."
  }

  # Parse arguments
  SYSTEM=""
  JSON_OUTPUT=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help; exit 0 ;;
      --json) JSON_OUTPUT=1; shift ;;
      *) SYSTEM="$1"; shift ;;
    esac
  done

  # Check for required system argument
  if [[ -z "$SYSTEM" ]]; then
    echo -e "''${RED}Error: System name is required.''${RESET}"
    show_help
    exit 1
  fi

  # Output file
  OUTPUT_FILE="/tmp/stig_''${SYSTEM}.json"

  echo -e "''${YELLOW}Fetching STIG configuration for system: $SYSTEM...''${RESET}"

  # Extract active STIG configuration
  ACTIVE_RESULT=$(nix eval --json ".#nixosConfigurations.\"$SYSTEM\".config.fmf.stig.active" 2>/dev/null)
  if [[ $? -ne 0 || -z "$ACTIVE_RESULT" ]]; then
    echo -e "''${RED}Error: Failed to fetch active STIG configuration for '$SYSTEM'.''${RESET}"
    exit 1
  fi

  # Extract inactive STIG configuration
  INACTIVE_RESULT=$(nix eval --json ".#nixosConfigurations.\"$SYSTEM\".config.fmf.stig.inactive" 2>/dev/null)
  if [[ $? -ne 0 || -z "$INACTIVE_RESULT" ]]; then
    echo -e "''${RED}Error: Failed to fetch inactive STIG configuration for '$SYSTEM'.''${RESET}"
    exit 1
  fi

  # Combine both into a single JSON object
  COMBINED_JSON=$(jq -n --argjson active "$ACTIVE_RESULT" --argjson inactive "$INACTIVE_RESULT" '{active: $active, inactive: $inactive}')

  # Save JSON result
  echo "$COMBINED_JSON" > "$OUTPUT_FILE"

  # Validate JSON
  if ! ${pkgs.jq}/bin/jq empty "$OUTPUT_FILE" >/dev/null 2>&1; then
    echo -e "''${RED}Error: Invalid JSON output. Could not process system '$SYSTEM'.''${RESET}"
    exit 1
  fi

  echo -e "''${GREEN}✓ STIG configuration saved to: $OUTPUT_FILE''${RESET}"

  # Print JSON output if requested
  if [[ $JSON_OUTPUT -eq 1 ]]; then
    cat "$OUTPUT_FILE"
  fi

  exit 0
''

