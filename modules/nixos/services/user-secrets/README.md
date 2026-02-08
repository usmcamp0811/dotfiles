# User Secrets Service for NixOS

## Overview

The User Secrets Service is a NixOS module designed to securely fetch and manage user-specific secrets from HashiCorp's Vault. It ensures that each user's secrets are stored in a dedicated location on the file system, accessible only to the respective user.

## Features

- **Securely Fetch Secrets**: Uses HashiCorp's Vault to securely fetch user secrets.
- **User-Specific Storage**: Places each user's secrets in a dedicated directory, ensuring privacy and security.
- **Configurable**: Easily specify which secrets to fetch for each user.

## Prerequisites

- A running instance of HashiCorp's Vault.
- NixOS system configuration.

## Configuration

To integrate the User Secrets Service into your NixOS system configuration:

1. **Enable the Service**:

   ```nix
   campground.services.user-secrets.enable = true;
   ```

2. **Specify Users and Their Secrets**:

   Define the users and the secrets you want to fetch for them:

   ```nix
   campground.services.user-secrets.users = {
     johndoe = {
       files = [ "api_key" "db_password" ];
     };
     // Add more users as needed
   };
   ```

   Note: The strings in the `files` list correspond to the keys of the secrets in the user's KV store in Vault.

3. **Vault Configuration**:

   Ensure the Vault Agent is enabled and configured with the appropriate settings:

   ```nix
   campground.services.vault-agent = {
     enable = true;
     settings = {
       vault = {
         address = "https://your-vault-address.com";
         role-id = "/path/to/role-id";
         secret-id = "/path/to/secret-id";
       };
     };
   };
   ```

## How It Works

1. The service uses the AppRole authentication method to securely communicate with Vault.
2. For each user, the service fetches the specified secrets from Vault.
3. The secrets are then stored in `/var/lib/vault/users/<username>` directory.
4. Proper file permissions are set to ensure that only the respective user can access their secrets.

## Limitations

- **File Names**: The file names (or secret keys) cannot contain periods (`.`). If they do, the service will fail, and the error might be challenging to diagnose.

## Conclusion

The User Secrets Service provides a streamlined way to manage user-specific secrets on NixOS systems using HashiCorp's Vault. With a simple configuration, you can ensure that each user's secrets are securely fetched and stored, providing both convenience and security. Always be cautious with the naming of your secrets to avoid potential issues.
