{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "vault-report";

  description = "A thing to check Vault to see if all the paths in the Flake are good";

  version = "1.0.0";

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
  pypkgs-build-requirements = {
    pandas = [ "versioneer" ];
  };
  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      (builtins.getAttr package super).overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg: if builtins.isString pkg then builtins.getAttr pkg super else pkg) build-requirements);
      })
    ) pypkgs-build-requirements
  );
  devshell-python = pkgs.poetry2nix.mkPoetryEnv  {
    projectDir = ./.;
    python = pkgs.python3;
    overrides = p2n-overrides;
    preferWheels = true;
  };
  thisProject = pkgs.stdenv.mkDerivation {
    name = "boat_models";
    src = ./.;  # Copy the entire project directory into the Nix store
    installPhase = ''
      mkdir -p $out
      cp -r ./* $out/
    '';
  };
  vault-report = pkgs.stdenv.mkDerivation {
    name = "vault-report";
    src = ./.;  # Copy the entire project directory into the Nix store
    installPhase = ''
      mkdir -p $out/bin
      cp -r ./* $out/
      cp ${getVaultPaths}/bin/get-vault-paths $out/bin
      echo "#!/usr/bin/env sh" > $out/bin/vault-report
      echo "${devshell-python}/bin/python3 ${thisProject}/vault-table.py" >> $out/bin/vault-report
      chmod +x $out/bin/vault-report
      echo "#!/usr/bin/env sh" > $out/bin/check-vault-paths
      echo "$out/bin/get-vault-paths | $out/bin/vault-report" >> $out/bin/check-vault-paths
      chmod +x $out/bin/check-vault-paths
    '';
};
  new-meta = with lib; {
    description = "A thing to check Vault to see if all the paths in the Flake are good";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta vault-report
