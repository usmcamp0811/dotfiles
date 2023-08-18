# Local User Passwords Module for NixOS

This module provides a way to set local user passwords using Vault in NixOS. It allows systems to securely manage user passwords, including the root user, by fetching them from a Vault instance.

## Features

- Configurable Vault settings
- Local user password management
- Root user password management
- Password update service

## Usage

To use this module, import it in your `./systems/x86_64-linux/<hostname>/default.nix` file and set the options according to your needs. Here is an example:

```nix
campground.system = {
    passwds = {
        enable = true;
        role-id = "/path/to/vault/role-id";
        secret-id = "/path/to/vault/secret-id";
        vault-address = "http://vault.campground.lan:8200";
    };
};
```

## Options

- `enable`: Whether or not to set local user passwords with Vault.
- `role-id`: Absolute path to the Vault role-id.
- `secret-id`: Absolute path to the Vault secret-id.
- `vault-address`: The address of your Vault.

