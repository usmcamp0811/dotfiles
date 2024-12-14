{ pkgs, checkVaultPath, }:
pkgs.writeShellScriptBin "get-vault-paths" ''
    # Function to display help
    show_help() {
      cat <<EOF
    Usage: get-vault-paths [options]

    This script fetches and optionally checks Vault paths for one or all systems.

    Options:
      -s, --system <system>  Specify a system to get Vault paths for.
      --check                Check the existence of the Vault paths using check-vault-path.
      -h, --help             Display this help message.

    Examples:
      get-vault-paths                 # Process all systems
      get-vault-paths --system mySystem --check  # Process and check Vault paths for mySystem

    Notes:
      - Ensure the necessary Nix configurations and Vault credentials are set up before use.

  EOF
    }

    # Parse arguments
    SYSTEM=""
    CHECK=0
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        -s|--system) SYSTEM="$2"; shift 2;;
        --check) CHECK=1; shift;;
        -h|--help) show_help; exit 0;;
        *) echo "Unknown argument: $1"; show_help; exit 1;;
      esac
    done

    # Create empty JSON object
    outputJson="{}"

    # Fetch list of systems
    if [ -z "$SYSTEM" ]; then
      systems=$(nix repl 2>/dev/null <<EOF
      :lf .
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
      :lf .
      lib.findVaultPaths 3 outputs.nixosConfigurations.$system.config.campground
  EOF
      )

      # Clean the list
      result=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[],"' | tr '\n' ' ')

      # Check each path with check-vault-path if --check is enabled
      for path in $result; do
        if [ $CHECK -eq 1 ]; then
          checkResult=$(${checkVaultPath}/bin/check-vault-path "$path"; echo $?)
          pathExistObj="{\"path\": \"$path\", \"exists\": $checkResult}"
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

    echo "$outputJson"
''
