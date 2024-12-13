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

### Remote Saving of AppRole Secrets

The `save-approle-secrets` script now supports saving AppRole secrets to a remote machine. Use the `--remote` option to specify the target machine and path. For example:

- **Command:** `save-approle-secrets my-approle --remote user@host:/path/to/secrets`
- **Behavior:** Saves the `role-id` and `secret-id` files to the specified remote location.

Each script is independently callable. Use `--help` with any script for additional details.
