{ pkgs, lib }:
let flake-src = ../../../../.;
in pkgs.writeShellScriptBin "system-check" ''
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
        OUTPUT_FILE="/tmp/stig_${SYSTEM}.json"

        echo -e "''${YELLOW}Fetching STIG configuration for system: $SYSTEM...''${RESET}"

        # Use Nix function to extract system STIG configuration
        RESULT=$(
          nix repl --quiet 2>/dev/null <<EOF
            :lf ${flake-src}
            sys = outputs.nixosConfigurations.$SYSTEM.config.campground.stig
            builtins.toJSON sys
  EOF
        )

        # Strip ANSI escape codes
        RESULT=$(echo "$RESULT" | ${pkgs.gnused}/bin/sed -r 's/\x1B\[[0-9;]*m//g')

        # Remove leading/trailing characters and clean up JSON formatting
        RESULT=$(echo "$RESULT" | ${pkgs.gnused}/bin/sed -e 's/^"//' -e 's/"$//' -e 's/%$//')

        # Validate JSON
        if ! echo "$RESULT" | ${pkgs.jq}/bin/jq empty >/dev/null 2>&1; then
          echo -e "''${RED}Error: Invalid JSON output. Could not process system '$SYSTEM'.''${RESET}"
          exit 1
        fi

        # Save JSON result
        echo "$RESULT" | ${pkgs.jq}/bin/jq '.' > "$OUTPUT_FILE"

        echo -e "''${GREEN}✓ STIG configuration saved to: $OUTPUT_FILE''${RESET}"

        # Print JSON output if requested
        if [[ $JSON_OUTPUT -eq 1 ]]; then
          cat "$OUTPUT_FILE"
        fi

        exit 0
''
