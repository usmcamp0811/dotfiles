{ pkgs }:

pkgs.writeShellScriptBin "create-approle" ''
  # Check if logged into Vault
  if ! ${pkgs.vault}/bin/vault token lookup > /dev/null 2>&1; then
    echo "Not logged into Vault. Exiting early."
    exit 1
  fi

  # Check if approle name is provided
  if [ -z "$1" ]; then
    echo "Approle name not provided. Exiting."
    exit 1
  fi

  # Set policy to campground by default or use provided second argument
  POLICY=''${2:-campground}

  # Create new approle with provided name and policy
  ${pkgs.vault}/bin/vault write auth/approle/role/$1 policies=$POLICY

  echo "Approle $1 created with policy $POLICY."
''
