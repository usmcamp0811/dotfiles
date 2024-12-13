{ pkgs }:
pkgs.writeShellScriptBin "save-approle-secrets" ''
  # Function to display help
  show_help() {
    cat <<EOF
  $(tput bold)$(tput setaf 3)Usage:$(tput sgr0) save-approle-secrets $(tput setaf 2)<approle_name> [--remote <user@host:path>]$(tput sgr0)

  $(tput bold)$(tput setaf 6)This script retrieves the role ID and secret ID for a specified AppRole in HashiCorp Vault$(tput sgr0)
  $(tput bold)$(tput setaf 6)and saves them securely locally or to a remote machine.$(tput sgr0)

  $(tput bold)$(tput setaf 3)Options:$(tput sgr0)
    $(tput setaf 2)<approle_name>$(tput sgr0)         The name of the AppRole whose secrets are to be retrieved $(tput bold)$(tput setaf 1)(required)$(tput sgr0).
    $(tput setaf 2)--remote <user@host:path>$(tput sgr0) Save secrets to a remote machine via SCP.

  $(tput bold)$(tput setaf 3)Behavior:$(tput sgr0)
    $(tput setaf 6)- Checks if the specified AppRole exists in Vault.$(tput sgr0)
    $(tput setaf 6)- Prompts for Vault login if not already authenticated.$(tput sgr0)
    $(tput setaf 6)- Retrieves the AppRole's role ID and secret ID.$(tput sgr0)
    $(tput setaf 6)- Saves the credentials to:
        $(tput setaf 2)- /var/lib/vault/<approle_name>/role-id$(tput sgr0)
        $(tput setaf 2)- /var/lib/vault/<approle_name>/secret-id$(tput sgr0)
      $(tput setaf 6)or to a specified remote location.$(tput sgr0)

  $(tput bold)$(tput setaf 3)Examples:$(tput sgr0)
    $(tput setaf 4)save-approle-secrets my-approle$(tput sgr0)
    $(tput setaf 4)save-approle-secrets my-approle --remote user@host:/path/to/secrets$(tput sgr0)
  EOF
  }

  # Check if --help or -h is passed
  if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
  fi

  set -e

  # Check that an AppRole name was provided
  if [ -z "$1" ]; then
    echo "$(tput bold)$(tput setaf 1)Error: AppRole name not provided.$(tput sgr0) $(tput setaf 3)Use --help for usage information.$(tput sgr0)"
    exit 1
  fi

  approle_name=$1
  shift

  # Check for remote option
  remote_path=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --remote)
        if [ -n "$2" ]; then
          remote_path="$2"
          shift
        else
          echo "$(tput bold)$(tput setaf 1)Error: --remote option requires an argument.$(tput sgr0)"
          exit 1
        fi
        ;;
      *)
        echo "$(tput bold)$(tput setaf 1)Error: Unknown option $1.$(tput sgr0)"
        exit 1
        ;;
    esac
    shift
  done

  # Verify if the AppRole exists in Vault
  if ${pkgs.vault-bin}/bin/vault read auth/approle/role/$approle_name > /dev/null 2>&1; then
    echo "$(tput bold)$(tput setaf 2)AppRole $approle_name exists.$(tput sgr0)"
  else
    echo "$(tput bold)$(tput setaf 1)AppRole $approle_name does not exist.$(tput sgr0)"
    exit 1
  fi

  # Retrieve the role ID and secret ID
  role_id=$(${pkgs.vault-bin}/bin/vault read -field=role_id auth/approle/role/$approle_name/role-id)
  secret_id=$(${pkgs.vault-bin}/bin/vault write -f -field=secret_id auth/approle/role/$approle_name/secret-id)

  if [ -n "$remote_path" ]; then
    # Save to remote machine
    echo "$(tput bold)$(tput setaf 3)Saving secrets to remote machine at $remote_path$(tput sgr0)"
    echo $role_id | ssh ''${remote_path%:*} "mkdir -p ''${remote_path#*:}/$approle_name && tee ''${remote_path#*:}/$approle_name/role-id" > /dev/null
    echo $secret_id | ssh ''${remote_path%:*} "tee ''${remote_path#*:}/$approle_name/secret-id" > /dev/null
    ssh ''${remote_path%:*} "chmod -R 0400 ''${remote_path#*:}/$approle_name"
    echo "$(tput bold)$(tput setaf 2)AppRole credentials saved to $remote_path/$approle_name.$(tput sgr0)"
  else
    # Save locally
    local_path="/var/lib/vault/$approle_name"
    echo "$(tput bold)$(tput setaf 3)Saving secrets locally to $local_path$(tput sgr0)"
    sudo mkdir -p $local_path
    sudo chmod 700 $local_path
    echo $role_id | sudo tee $local_path/role-id > /dev/null
    echo $secret_id | sudo tee $local_path/secret-id > /dev/null
    sudo chmod -R 0400 $local_path
    echo "$(tput bold)$(tput setaf 2)AppRole credentials saved to $local_path.$(tput sgr0)"
  fi
''
