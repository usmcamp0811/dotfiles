# HashiCorp Vault with Database Engine on NixOS: A Quick Guide

This guide is compatible with Vault 1.8+ and NixOS 21.05+, and will walk you through setting up HashiCorp Vault's Database Secrets Engine on NixOS to manage PostgreSQL database passwords.

## Pre-requisites

- Vault installed and running
- PostgreSQL installed and running
- Basic understanding of Vault & NixOS
- Basic-to-Advanced understanding of databases

---

## Step 1: Enable the Database Engine in Vault

Enable the Vault Database Secrets Engine at the path `campground-dbs`.

```bash
vault secrets enable -path=campground-dbs database
```

---

## Step 2: Configure PostgreSQL Connection

Next, you'll need to configure the connection to your PostgreSQL database. **Note:** In a production environment, avoid hardcoding passwords and usernames.

```bash
vault write campground-dbs/config/my-postgresql-database \
    plugin_name=postgresql-database-plugin \
    allowed_roles="*" \
    connection_url="postgresql://{{username}}:{{password}}@localhost:5432/mydatabase?sslmode=disable" \
    username="postgres" \
    password="postgrespassword"
```

---

## Step 3: Create a Role for Credential Generation

Create a role that will map to a set of PostgreSQL permissions.

```bash
vault write campground-dbs/roles/mydb-app \
    db_name=my-postgresql-database \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
```

---

## Step 4: Generate Credentials

Generate a new set of credentials based on the `mydb-app` role. These credentials can be used to access the database with the permissions specified in Step 3.

```bash
vault read campground-dbs/creds/mydb-app
```

---

## NixOS: Testing with Temporary Databases

You can use NixOS's `nixosTests` to create temporary PostgreSQL databases for testing. Here's a simplified example. After running the test, examine the test logs for results or debug issues.

```nix
{ pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_13;
    initialScript = pkgs.writeText "postgresql-init.sql" ''
      CREATE DATABASE mydatabase;
      CREATE USER postgres WITH PASSWORD 'postgrespassword';
      GRANT ALL PRIVILEGES ON DATABASE mydatabase TO postgres;
    '';
  };
}

Run this with `nixos-rebuild test`.
```

---

## Additional DB Types

Vault also supports other databases like MySQL, MongoDB, etc. The setup is similar; you just have to change the plugin name and connection parameters.

