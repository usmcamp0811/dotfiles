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

  checkVaultPath = pkgs.writeShellScriptBin "check-vault-path" ''

    full_path="$1"

    if vault kv get $1 > /dev/null 2>&1; then
      # echo "KV1 exists"
      exit 0
    fi

    # echo "Path does not exist."
    exit 1

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
