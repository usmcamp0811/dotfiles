{ pkgs, lib, checkVaultPath, }:
let flake-src = ../../../../.;
in pkgs.writeShellScriptBin "system-vault-check" ''
      # Define colors for output
      RED="\033[31m"
      GREEN="\033[32m"
      YELLOW="\033[33m"
      RESET="\033[0m"

      # Function to display help
      show_help() {
        echo -e "''${YELLOW}Usage:''${RESET}"
        echo -e "  system-vault-check <system-name> [--json]"
        echo
        echo -e "''${YELLOW}Options:''${RESET}"
        echo -e "  -h, --help          Show this help message."
        echo -e "  --json              Output results in JSON format."
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

      # Use Nix function to extract Vault paths and fields
      RESULT=$(
        nix repl 2>/dev/null <<EOF
          :lf ${flake-src}
          sys = lib.findVaultPathsAndFields outputs.nixosConfigurations.$SYSTEM.config.campground
          builtins.toJSON sys
  EOF
      )
      RESULT=$(printf "$RESULT" | ${pkgs.gnused}/bin/sed -r 's/\x1B\[[0-9;]*m//g' | ${pkgs.gnused}/bin/sed -e 's/^"//' -e 's/"$//' -e 's/%$//' | ${pkgs.jq}/bin/jq)


      # Check if Nix evaluation succeeded
      if [[ $? -ne 0 || -z "$RESULT" ]]; then
        echo -e "''${RED}Error: Failed to evaluate system '$SYSTEM'.''${RESET}"
        exit 1
      fi

      # Initialize error tracking
      ERROR_FOUND=0
      MISSING_ITEMS=()

      # Process JSON result
      echo "$RESULT" | ${pkgs.jq}/bin/jq -c '.[]' | while read -r item; do
        VAULT_PATH=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.path')
        FIELDS=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.fields[]')

        # Check if Vault path exists
        vault kv get "$VAULT_PATH" &>/dev/null
        if [[ $? -ne 0 ]]; then
          echo -e "''${RED}✗ Vault path does not exist: $VAULT_PATH''${RESET}"
          ERROR_FOUND=1
          MISSING_ITEMS+=("{\"path\": \"$VAULT_PATH\", \"fields\": null}")
          continue
        else
          if [[ $JSON_OUTPUT -eq 0 ]]; then
            echo -e "''${GREEN}✓ Vault path exists: $VAULT_PATH''${RESET}"
          fi
        fi

        # Check each field in the Vault path
        echo "$FIELDS" | while read -r FIELD; do
          vault kv get -field="$FIELD" "$VAULT_PATH" &>/dev/null
          if [[ $? -ne 0 ]]; then
            export ERROR_FOUND=1
            if [[ $JSON_OUTPUT -eq 0 ]]; then
              echo -e "''${RED}✗ Field does not exist: $FIELD in $VAULT_PATH''${RESET}"
            fi
            MISSING_ITEMS+=("{\"path\": \"$VAULT_PATH\", \"field\": \"$FIELD\"}")
          else
            if [[ $JSON_OUTPUT -eq 0 ]]; then
              echo -e "''${GREEN}✓ Field exists: $FIELD''${RESET}"
            fi
          fi
        done
      done
      echo "ERRORS => $ERROR_FOUND"
      # Report missing items if any
      if [[ $ERROR_FOUND -eq 1 ]]; then
        if [[ $JSON_OUTPUT -eq 1 ]]; then
          echo "''${MISSING_ITEMS[@]}" | ${pkgs.jq}/bin/jq
        else
          echo -e "''${RED}Some paths or fields are missing:''${RESET}"
          printf '%s\n' "''${MISSING_ITEMS[@]}"
        fi
        exit 1
      else
        echo -e "''${GREEN}All Vault paths and fields exist.''${RESET}"
        exit 0
      fi
''
