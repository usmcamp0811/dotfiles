{pkgs}:
pkgs.writeShellScriptBin "create-approle" ''


  # Check if already logged into Vault
  vault_status=$(${pkgs.vault}/bin/vault status -format=json 2>/dev/null)

  if [ $? -eq 0 ]; then
    echo "Already logged into Vault."
  else
    echo "Please login to Vault..."
    ${pkgs.vault}/bin/vault login || { echo "Vault login failed."; exit 1; }
  fi

  # Check that login was successful
  if [ $? -ne 0 ]; then
    echo "Vault login failed."
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
