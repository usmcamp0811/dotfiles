{ mkShell
, pkgs
, config
, lib
, self
, ...
}:
with lib;
with lib.campground;
let 
  checkVaultPath = pkgs.writeShellScriptBin "check-vault-path" ''
    full_path="$1"

    # Check for PKI engines
    if [[ "$full_path" == *"/issue/"* ]]; then
      engine_path=$(echo "$full_path" | awk -F '/issue/' '{print $1}')
      role=$(echo "$full_path" | awk -F '/issue/' '{print $2}')

      if vault read -format=json "$engine_path/roles/$role" > /dev/null 2>&1; then
        exit 0
      fi
    else
      # Try listing the parent path
      parent_path=$(dirname "$full_path")
      if [ "$parent_path" == "." ]; then
        parent_path=""
      fi

      output=$(vault list -format=json "$parent_path" 2>&1)
      if [[ "$output" == *"$full_path"* || "$output" == *"listing is not allowed"* ]]; then
        exit 0
      elif vault kv get $1 > /dev/null 2>&1; then
        exit 0
      fi
    fi

    exit 1
  '';
  # checkVaultPath = pkgs.writeShellScriptBin "check-vault-path" ''
  #   full_path="$1"
  #
  #   # Check for PKI engines
  #   if [[ "$full_path" == *"/issue/"* ]]; then
  #     engine_path=$(echo "$full_path" | awk -F '/issue/' '{print $1}')
  #     role=$(echo "$full_path" | awk -F '/issue/' '{print $2}')
  #     
  #     if vault read -format=json "$engine_path/roles/$role" > /dev/null 2>&1; then
  #       exit 0
  #     fi
  #   else
  #     if vault kv get $1 > /dev/null 2>&1; then
  #       exit 0
  #     fi
  #   fi
  #
  #   exit 1
  # '';
  # test = builtins.toJSON (findVaultPaths 8 config.campground);
  getVaultPaths = pkgs.writeShellScriptBin "get-vault-paths" ''
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
      result=$(nix repl 2>/dev/null <<EOF
    :lf .
    lib.findVaultPaths 3 outputs.nixosConfigurations.$system.config.campground
    EOF
      )

      # Clean the list
      result=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[],"' | tr '\n' ' ')

      # Initialize an empty array for path checks
      pathChecks=[]

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
  '';

in
mkShell {
  buildInputs = [
    pkgs.deadnix
    pkgs.hydra-check
    pkgs.nix-diff
    pkgs.nix-index
    pkgs.nix-prefetch-git
    pkgs.nixpkgs-fmt
    pkgs.nixpkgs-hammering
    pkgs.nixpkgs-lint
    pkgs.snowfallorg.flake
    pkgs.statix
    getVaultPaths
    checkVaultPath
  ];

  shellHook = ''
    echo 🏕️ Welcome to the Campground
    # Additional setup can go here

  '';
}
