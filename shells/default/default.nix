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
  getVaultPaths = pkgs.writeShellScriptBin  "get-vault-paths" ''
    # Fetch list of systems
    systems=$(nix repl 2>/dev/null <<EOF
    :lf .
    builtins.attrNames outputs.nixosConfigurations
    EOF
    )

    # Strip ANSI escape codes and remove unwanted characters
    systems=$(echo "$systems" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[],"' | tr '\n' ' ')

    echo "SYS: $systems"

    # Initialize empty array to collect all paths
    allPaths=()

    # Loop through each system and fetch paths
    for system in $systems; do
        result=$(nix repl 2>/dev/null <<EOF
    :lf .
    lib.findVaultPaths 3 outputs.nixosConfigurations.$system.config.campground
    EOF
        )
        
        # Strip ANSI escape codes and remove unwanted characters
        result=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[],"' | tr '\n' ' ')
        
        # Add to allPaths
        allPaths+=($result)
    done

    # Dedupe the list and save it as a variable
    uniquePaths=$(echo "''${allPaths[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

    echo "$uniquePaths"
  '';

  checkVaultPath = pkgs.writeShellScriptBin "check-vault-path" ''

    full_path="$1"

    if vault kv get $1 > /dev/null 2>&1; then
      echo "KV1 exists"
      exit 0
    fi

    echo "Path does not exist."
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
