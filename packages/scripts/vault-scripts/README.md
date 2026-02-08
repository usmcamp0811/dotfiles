# Vault Scripts Usage Guide

This package provides the following Vault-related scripts:

1. **init-vault**  
   Initializes and unseals a HashiCorp Vault server.  
   **Usage:** `init-vault [--help]`

2. **create-approle**  
   Creates a new AppRole in HashiCorp Vault with an optional policy.  
   **Usage:** `create-approle <approle-name> [policy]`

3. **save-approle-secrets**  
   Retrieves and securely saves the role ID and secret ID for an AppRole, either locally or on a remote machine.  
   **Usage:** `save-approle-secrets <approle-name> [--remote <user@host:path>]`

   - **Options:**
     - `<approle-name>`: The name of the AppRole whose secrets are to be retrieved (required).
     - `--remote <user@host:path>`: Save the secrets to a specified remote machine using SCP.

4. **check-vault-path**  
   Checks the existence of a specific path in HashiCorp Vault.  
   **Usage:** `check-vault-path <vault-path>`

5. **vault-crawler**  
   Recursively crawls a Vault path and generates commands to recreate secrets with placeholders for their values.  
   **Usage:** `vault-crawler <base_path> [--help]`

   - **Options:**

     - `<base_path>`: The Vault path to crawl (required).
     - `--help`: Show detailed usage instructions for the script.

   - **Example Output:**  
     When run, the script generates `vault kv put` commands for each secret it finds:

     ```bash
     vault kv put secret/campground/mlflow key1={PLACEHOLDER} key2={PLACEHOLDER}
     vault kv put secret/campground/github token={PLACEHOLDER}
     ```

   - **Features:**
     - Handles both KV v1 and KV v2 secret engines.
     - Provides helpful color-coded outputs for errors, commands, and general information.

6. **system-vault-check**  
   Checks the Vault KV paths and fields required by a specific system configuration in my NixOS dotfiles.  
   **Usage:** `system-check <system-name>`

   - **Options:**

     - `<system-name>`: The name of the system to check (required).
     - `--help`: Display detailed usage instructions.

   - **Features:**

     - Validates the existence of all required Vault KV paths and their fields.
     - Outputs errors for missing paths or fields with helpful color-coded messages.
     - Returns `exit 0` if all paths and fields exist, or `exit 1` if any are missing.
     - Reduces deployment timeouts and failures by pre-checking Vault configurations.

   - **Requirements:**

     - The `VAULT_ADDR` environment variable must be set.
     - You must be logged into Vault before running the script.

   - **Example:**
     ```bash
     system-check my-system
     ```

7. **raft-recovery**  
   Recovers a Vault Raft cluster node by creating a `peers.json` file in the Raft storage directory and restarting the Vault service.  
   **Usage:** `raft-recovery`

   - **Steps Performed:**

     - Stops the Vault service.
     - Creates a `peers.json` file with the current node's information based on hostname and IP.
     - Restarts the Vault service to initiate recovery.
     - Provides instructions for verifying recovery and rejoining additional nodes to the cluster.

   - **Example:**
     ```bash
     raft-recovery
     ```

8. **delete-rejoin-raft**  
   Deletes all Vault data and reinitializes the current node to rejoin a Vault Raft cluster.  
   **Usage:** `delete-rejoin-raft`

   - **Steps Performed:**

     - Confirms if you want to proceed with deleting existing Vault data.
     - Stops the Vault service.
     - Deletes all Vault data in `/var/lib/vault/data`.
     - Restarts the Vault service.
     - Sets the `VAULT_ADDR` environment variable.
     - Prompts for the Raft leader's hostname to join the cluster.
     - Checks if Vault is unsealed and unseals it if necessary.
     - Joins the Raft cluster using the leader's address.
     - Lists the current peers in the Raft cluster.

   - **Example:**
     ```bash
     delete-rejoin-raft
     ```

---

### Recommended Usage

#### Scenario 1: Brand New System with a Brand New Vault

If you have a brand-new system with a freshly installed Vault instance, run the scripts in the following order:

1. `init-vault` to initialize and unseal the Vault server.
2. `create-approle` to create AppRoles as needed.
3. `save-approle-secrets` to securely save AppRole secrets for later use.

#### Scenario 2: New System with an Already Configured Vault

If the Vault instance is already initialized and configured, run:

1. `create-approle` to create additional AppRoles as needed.
2. `save-approle-secrets` to securely save AppRole secrets for later use.

#### Scenario 3: Recreating Vault Secrets in a Different Environment

If you need to migrate or recreate Vault secrets in another environment:

1. Use `vault-crawler` to generate `vault kv put` commands for a specific Vault path.
2. Run the generated commands in the new environment to recreate the secrets.

#### Scenario 4: Validating Vault Configurations for System Deployments

Before deploying a NixOS system configuration, run:

1. `system-check <system-name>` to validate that all required Vault paths and fields exist.
2. Proceed with the deployment if the check passes.

#### Scenario 5: Recovering or Rejoining a Vault Raft Cluster

1. If the Vault Raft cluster requires recovery, use `raft-recovery` to recover a single node.
2. If a node needs to rejoin the cluster, use `delete-rejoin-raft` to reset and rejoin it.

---

### Remote Saving of AppRole Secrets

The `save-approle-secrets` script supports saving AppRole secrets to a remote machine. Use the `--remote` option to specify the target machine and path. For example:

- **Command:** `save-approle-secrets my-approle --remote user@host:/path/to/secrets`
- **Behavior:** Saves the `role-id` and `secret-id` files to the specified remote location.

---

### Detailed Help for Each Script

Each script is independently callable. Use `--help` with any script for additional details. For example:

```bash
vault-crawler --help
```
