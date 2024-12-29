{ pkgs }:
pkgs.writeShellScriptBin "raft-recovery" ''
  set -e  # Exit immediately if a command exits with a non-zero status

  # Function to print usage and exit
  usage() {
    echo "Usage: $0"
    echo "This script performs the following steps to recover a Vault Raft cluster node:"
    echo "1. Stops the Vault service on the current node."
    echo "2. Creates a peers.json file in the Raft storage directory with the current node's information."
    echo "   - The node ID is based on the hostname (vault-node-\$(hostname))."
    echo "   - The IP address is derived from the first IP of the current host."
    echo "3. Restarts the Vault service to initiate recovery."
    echo "4. Outputs instructions for verifying recovery and rejoining additional nodes to the cluster."
    exit 1
  }

  # Ensure the script is run as root
  if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi

  # Variables
  RAFT_PATH="/var/lib/vault/data/raft"
  PEERS_JSON_PATH="$RAFT_PATH/peers.json"
  NODE_ID="vault-node-$(hostname)"

  # Step 1: Stop the Vault service
  systemctl stop vault

  # Step 2: Create the raft directory if it doesn't exist
  mkdir -p $RAFT_PATH

  # Step 3: Create the peers.json file
  cat <<EOF > $PEERS_JSON_PATH
  [
    {
      "id": "$NODE_ID",
      "address": "$(hostname):8201",
      "non_voter": false
    }
  ]
  EOF

  # Step 4: Start the Vault service
  systemctl start vault

  # Step 5: Print placeholder instructions for recovering other nodes
  cat <<EOM
  Vault service has been restarted with a new peers.json file.

  Next steps:
  1. Verify the Vault service is unsealed and running on this node using:
     vault status

  2. Check logs to ensure recovery has succeeded:
     journalctl -u $VAULT_SERVICE --no-pager

  3. Placeholder: Write and run a script to join additional nodes to the cluster.
     This script should handle joining new nodes with the command:
     vault operator raft join <leader-address>

  4. Confirm the cluster status using:
     vault operator raft list-peers
  EOM
''
