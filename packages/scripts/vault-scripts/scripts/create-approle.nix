{ pkgs }:
pkgs.writeShellScriptBin "create-approle" ''
    # Function to display help
  show_help() {
    cat <<EOF
  $(tput bold)$(tput setaf 3)Usage:$(tput sgr0) create-approle <$(tput setaf 2)approle-name$(tput sgr0)> [$(tput setaf 2)policy$(tput sgr0)]

  $(tput bold)$(tput setaf 6)This script creates a new AppRole in HashiCorp Vault with the specified policy.$(tput sgr0)

  $(tput bold)$(tput setaf 3)Options:$(tput sgr0)
    $(tput setaf 2)approle-name$(tput sgr0)  The name of the AppRole to create $(tput bold)$(tput setaf 1)(required)$(tput sgr0).
    $(tput setaf 2)policy$(tput sgr0)        The Vault policy to associate with the AppRole. Defaults to $(tput bold)campground$(tput sgr0).

  $(tput bold)$(tput setaf 3)Examples:$(tput sgr0)
    $(tput setaf 4)create-approle my-approle$(tput sgr0)
    $(tput setaf 4)create-approle my-approle my-custom-policy$(tput sgr0)

  $(tput bold)$(tput setaf 3)Notes:$(tput sgr0)
    $(tput setaf 1)- You must be logged into Vault before running this script.$(tput sgr0)
    $(tput setaf 1)- If not logged in, the script will prompt you to log in.$(tput sgr0)
  EOF
  }

    # Check if --help or -h is passed
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
      show_help
      exit 0
    fi

    # Check if already logged into Vault
    vault_status=$(${pkgs.vault-bin}/bin/vault status -format=json 2>/dev/null)

    if [ $? -eq 0 ]; then
      echo "Already logged into Vault."
    else
      echo "Please log in to Vault..."
      ${pkgs.vault-bin}/bin/vault login || { echo "Vault login failed."; exit 1; }
    fi

    # Check that login was successful
    if [ $? -ne 0 ]; then
      echo "Vault login failed."
      exit 1
    fi

    # Check if approle name is provided
    if [ -z "$1" ]; then
      echo "Error: AppRole name not provided. Use --help for usage information."
      exit 1
    fi

    # Set policy to "campground" by default or use provided second argument
    POLICY=''${2:-campground}

    # Create new approle with provided name and policy
    ${pkgs.vault-bin}/bin/vault write auth/approle/role/$1 policies=$POLICY

    echo "AppRole $1 created with policy $POLICY."
''
