# NixOS PostgreSQL Module with Vault Integration

## Overview

This is a custom NixOS module designed to manage PostgreSQL databases. It features Vault-based secret management, customizable databases, and role-based user permissions.

## How To Use This Module

To enable and configure this PostgreSQL module, include it in your `configuration.nix` and set your desired options in the `campground.services.postgresql` attribute set.

### Basic Usage Example

```nix
campground.services = {
  postgresql = {
    enable = true;
    databases = [
      {
        name = "example_db";
        user = "example_user";
      }
    ];
  };
};
```

## Options

### `enable`

- **Type**: Boolean
- **Default**: `false`

Enables the PostgreSQL service.

### `role-id` and `secret-id`

- **Type**: String

Absolute path to the Vault role and secret IDs.

### `vault-path`

- **Type**: String
- **Default**: `"secret/campground/database-users"`

Path in Vault where the database user credentials are stored.

### `kvVersion`

- **Type**: Enum (`"v1"` or `"v2"`)
- **Default**: `"v2"`

Version of Vault's Key-Value store.

### `databases`

- **Type**: List of submodules
- **Example**:

  ```nix
  databases = [
    {
      name = "example_db";
      user = "example_user";
    }
  ];
  ```

Define the databases to be initialized and their respective users.

### `package`

- **Type**: Package
- **Default**: `pkgs.postgresql_13`

Specifies which PostgreSQL package version to use.

### `enableTCPIP`

- **Type**: Boolean
- **Default**: `false`

Allows TCP/IP connections to PostgreSQL.

### `authentication`

- **Type**: String
- **Default**: [Default settings]

Configuration for PostgreSQL's `pg_hba.conf`.

### `extraInit`

- **Type**: String
- **Default**: `""`

Additional initialization steps for PostgreSQL.

## Nuances

- **Vault Integration**: Ensure that Vault is accessible and properly configured, as the module tightly integrates with Vault for secret management.
  
- **Firewall**: If you enable TCP/IP, port `5432` will be opened, exposing your PostgreSQL server.

- **User Management**: User permissions are set automatically based on your configuration, including setting passwords via Vault.

- **Authentication**: Be cautious when setting up the `authentication` option, as it directly influences your security settings.

- **Dependencies**: This module expects the existence of other `campground` services like `vault-agent`. Make sure those are set up correctly.
