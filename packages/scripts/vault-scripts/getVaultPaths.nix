{
  pkgs,
  checkVaultPath,
}:
pkgs.writeShellScriptBin "get-vault-paths" ''
  # Create empty JSON object
  outputJson="{}"

  # Fetch list of systems
  systems=$(nix repl 2>/dev/null <<EOF
  :lf .
  builtins.attrNames outputs.nixosConfigurations
  EOF
  )

  # Clean the list
  systems=$(echo "$systems" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[],"' | tr '\n' ' ')

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

    # Check each path with check-vault-path
    for path in $result; do
      checkResult=$(${checkVaultPath}/bin/check-vault-path "$path"; echo $?)
      pathExistObj="{\"path\": \"$path\", \"exists\": $checkResult}"
      pathChecks+=("$pathExistObj")
    done

    # Convert pathChecks array to JSON array string
    pathChecksJson=$(printf "%s\n" "''${pathChecks[@]}" | ${pkgs.jq}/bin/jq -c -s '.')

    # Add to output JSON
    outputJson=$(echo "$outputJson" | ${pkgs.jq}/bin/jq --arg system "$system" --argjson paths "$pathChecksJson" '. + {($system): $paths}')

  done

  echo "$outputJson"
''
