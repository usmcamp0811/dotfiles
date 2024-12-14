{ pkgs, checkVaultPath, }:
let flake-src = ../../../../.;
in pkgs.writeShellScriptBin "get-vault-paths" ''
    # Define colors
    RED="\033[31m"
    GREEN="\033[32m"
    CYAN="\033[36m"
    YELLOW="\033[33m"
    RESET="\033[0m"

    # Function to display help
    show_help() {
      echo -e "''${CYAN}Usage:''${RESET}"
      echo -e "  get-vault-paths [''${YELLOW}options''${RESET}]"
      echo
      echo -e "''${CYAN}Description:''${RESET}"
      echo -e "  This script fetches and optionally checks Vault paths for one or all systems."
      echo
      echo -e "''${CYAN}Options:''${RESET}"
      echo -e "  ''${YELLOW}-s, --system <system>''${RESET}  Specify a system to get Vault paths for."
      echo -e "  ''${YELLOW}--check''${RESET}                Check the existence of the Vault paths using ''${GREEN}check-vault-path''${RESET}."
      echo -e "  ''${YELLOW}--json''${RESET}                 Output results in JSON format for redirection."
      echo -e "  ''${YELLOW}-h, --help''${RESET}             Display this help message."
      echo
      echo -e "''${CYAN}Examples:''${RESET}"
      echo -e "  ''${GREEN}get-vault-paths''${RESET}                 # Process all systems"
      echo -e "  ''${GREEN}get-vault-paths --system mySystem --check''${RESET}  # Process and check Vault paths for mySystem"
      echo -e "  ''${GREEN}get-vault-paths --json > output.json''${RESET}       # Save results to a JSON file"
      echo
      echo -e "''${CYAN}Notes:''${RESET}"
      echo -e "  - Ensure the necessary Nix configurations and Vault credentials are set up before use."
    }

    # Parse arguments
    SYSTEM=""
    CHECK=0
    JSON_OUTPUT=0
    ERROR_FOUND=0
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        -s|--system) SYSTEM="$2"; shift 2;;
        --check) CHECK=1; shift;;
        --json) JSON_OUTPUT=1; shift;;
        -h|--help) show_help; exit 0;;
        *) echo -e "''${RED}Unknown argument: $1''${RESET}"; show_help; exit 1;;
      esac
    done

    # Create empty JSON object
    outputJson="{}"

    # Fetch list of systems
    if [ -z "$SYSTEM" ]; then
      systems=$(nix repl 2>/dev/null <<EOF
      :lf ${flake-src}
      builtins.attrNames outputs.nixosConfigurations
  EOF
      )
      systems=$(echo "$systems" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[],"' | tr '\n' ' ')
    else
      systems="$SYSTEM"
    fi

    # Loop through each system and fetch paths
    for system in $systems; do
      # Reset the pathChecks for each system
      pathChecks=()

      result=$(nix repl 2>/dev/null <<EOF
      :lf ${flake-src}
      lib.findVaultPaths 3 outputs.nixosConfigurations.$system.config.campground
  EOF
      )

      # Clean the list of vault paths
      result=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[],"' | tr '\n' ' ')

      # Check each path with check-vault-path if --check is enabled
      for path in $result; do
        if [ $CHECK -eq 1 ]; then
          checkResult=$(${checkVaultPath}/bin/check-vault-path "$path"; echo $?)
          if [ "$checkResult" -eq 0 ]; then
            checkExists="true"
            if [ $JSON_OUTPUT -eq 0 ]; then
              echo -e "''${GREEN}✓ Path exists: $path''${RESET}"
            fi
          else
            checkExists="false"
            ERROR_FOUND=1
            if [ $JSON_OUTPUT -eq 0 ]; then
              echo -e "''${RED}✗ Path does not exist: $path''${RESET}"
            fi
          fi
          pathExistObj="{\"path\": \"$path\", \"exists\": $checkExists}"
          pathChecks+=("$pathExistObj")
        else
          pathChecks+=("{\"path\": \"$path\"}")
        fi
      done

      # Convert pathChecks array to JSON array string
      pathChecksJson=$(printf "%s\n" "''${pathChecks[@]}" | ${pkgs.jq}/bin/jq -c -s '.')

      # Add to output JSON
      outputJson=$(echo "$outputJson" | ${pkgs.jq}/bin/jq --arg system "$system" --argjson paths "$pathChecksJson" '. + {($system): $paths}')
    done

    # Handle output based on flags
    if [ $JSON_OUTPUT -eq 1 ]; then
      echo "$outputJson"
      exit 0
    else
      if [ $CHECK -eq 1 ]; then
        if [ $ERROR_FOUND -eq 1 ]; then
          exit 1
        else
          exit 0
        fi
      fi
    fi
''
