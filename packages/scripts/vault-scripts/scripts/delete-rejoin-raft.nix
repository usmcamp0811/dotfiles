{ pkgs }:
pkgs.writeShellScriptBin "delete-rejoin-raft" ''
  set -e  # Exit immediately if a command exits with a non-zero status

  # Function to print usage and exit
  usage() {
    echo "Usage: $0"
    echo "This script performs the following steps to rejoin a Vault Raft cluster:"
    echo "1. Confirms if you want to proceed with deleting existing Vault data."
    echo "2. Stops the Vault service."
    echo "3. Deletes all Vault data in /var/lib/vault/data."
    echo "4. Restarts the Vault service."
    echo "5. Sets the VAULT_ADDR environment variable to http://\$(hostname):8200."
    echo "6. Prompts for the Raft leader's hostname to join the cluster."
    echo "7. Checks if Vault is unsealed and unseals it if necessary."
    echo "8. Executes the raft join command to join the cluster."
    echo "9. Lists the current peers in the Raft cluster."
    exit 1
  }

  # Ensure the script is run as root
  if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi

  # Confirm deletion of Vault data
  read -p "Are you sure you want to proceed? This will delete all Vault data. (yes/no): " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Operation aborted."
    exit 1
  fi

  # Variables
  VAULT_SERVICE="vault"
  DATA_DIR="/var/lib/vault/data"
  VAULT_ADDR="http://$(hostname):8200"
  export VAULT_ADDR

  # Step 1: Stop the Vault service
  systemctl stop $VAULT_SERVICE

  # Step 2: Delete all Vault data
  rm -rf $DATA_DIR/*

  # Step 3: Start the Vault service
  systemctl start $VAULT_SERVICE

  # Step 4: Prompt for Raft leader hostname
  read -p "Enter the hostname or IP of the Raft leader: " RAFT_LEADER_HOSTNAME

  # Step 5: Check if Vault is unsealed
  SEALED=$(${pkgs.vault-bin}/bin/vault status -format=json | ${pkgs.jq}/bin/jq -r '.sealed')
  if [[ "$SEALED" == "true" ]]; then
    echo "Vault is sealed. Please enter unseal keys to unseal Vault."
    for i in {1..3}; do
      read -s -p "Enter unseal key $i: " UNSEAL_KEY
      echo
      ${pkgs.vault-bin}/bin/vault operator unseal $UNSEAL_KEY
    done
    SEALED=$(${pkgs.vault-bin}/bin/vault status -format=json | ${pkgs.jq}/bin/jq -r '.sealed')
    if [[ "$SEALED" == "true" ]]; then
      echo "Vault is still sealed. Please check unseal keys and try again."
      exit 1
    fi
  fi

  # Step 6: Join the Raft cluster
  ${pkgs.vault-bin}/bin/vault operator raft join http://$RAFT_LEADER_HOSTNAME:8200

  # Step 7: List the current peers in the Raft cluster
  ${pkgs.vault-bin}/bin/vault operator raft list-peers
''
