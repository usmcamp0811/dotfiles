# Vault Setup on NixOS

This README outlines the steps required to set up Vault on a NixOS system.

## Prerequisites

- Make sure you have run `update-sys` to update your system.
  
## Initial Setup

1. **Initialize Vault**: After updating your system, you'll need to initialize and unseal Vault.

## Configuring Vault Policy Agent

1. **Create AppRole**: To make the Vault Policy Agent work, you'll need to create an AppRole specifically for it.

2. **Assign Policy**: Assign the `vault-policies.hcl` policy to the newly created AppRole.

3. **Store Credentials**: Save the `role-id` and `secret-id` in `/var/lib/vault/`. If you prefer a different location, make sure to specify it in your configuration.

## Commands

Here are the shell commands to execute the above steps:

```sh
# Change ownership of the Vault data directory
sudo chown -R vault:vault /persist/vault

# Write the Vault policy
vault policy write vault-policy vault-policies.hcl

# Enable AppRole and assign the policy
vault auth enable approle
vault write auth/approle/role/vault token_policies="vault-policy"

# Retrieve and store the RoleID and SecretID
vault read -field=role_id auth/approle/role/vault/role-id | sudo tee /var/lib/vault/role-id
vault write -f -field=secret_id auth/approle/role/vault/secret-id | sudo tee /var/lib/vault/secret-id

# Set appropriate permissions
sudo chown vault:vault /var/lib/vault/*-id
sudo chmod 0400 /var/lib/vault/*-id
```

After completing these steps, your Vault setup should be operational.

