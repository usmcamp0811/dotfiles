+++
author = "Matt Camp"
title = "HashiCorp Vault with Database Engine on NixOS"
date = "2023-10-15"
description = "Learn how to securely manage PostgreSQL credentials on NixOS with HashiCorp Vault's Database Secrets Engine. This guide walks you through setting up PostgreSQL, enabling Vault’s database engine, and dynamically generating time-limited credentials for enhanced security."
tags = [
    "Nix",
    "Vault"
]
categories = [
    "Nix",
    "DevOps",
    "Tutorial"
]
+++

# HashiCorp Vault with Database Engine on NixOS: A Quick Guide

This guide is compatible with Vault 1.8+ and NixOS 21.05+, and will walk you through setting up HashiCorp Vault's Database Secrets Engine on NixOS to manage PostgreSQL database passwords.

## Pre-requisites

- Vault installed and running
- PostgreSQL installed and running
- Basic understanding of Vault & NixOS
- Basic-to-Advanced understanding of databases

---

## Step 0: Initialize PostgreSQL Database on NixOS

Add the following configuration to your `configuration.nix` to create an initial PostgreSQL database and user.
Read [this](https://yuweisung.medium.com/postgresql-pg-hba-conf-explained-part1-3792de3d64c2) to learn more about PostgreSQL authentication.

```nix
{ pkgs, ... }:
{
    networking.firewall.allowedTCPPorts = [ 5432 ];  # Open PostgreSQL port
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_13;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        # Allow only local connections for the root user
        local all postgres peer
        # Require password for Vault-generated users over the network
        host  all  all  10.8.0.1/24  md5
        # Deny other remote connections
        host  all  all  0.0.0.0/0  reject
        host  all  all  ::0/0  reject
      '';
      initialScript = pkgs.writeText "postgresql-init.sql" ''
        CREATE DATABASE mydatabase;
        CREATE USER postgres WITH PASSWORD 'postgrespassword';
        GRANT ALL PRIVILEGES ON DATABASE mydatabase TO postgres;
      '';
    };
}
```

Run `nixos-rebuild switch` to apply the changes.

---

## Step 1: Enable the Database Engine in Vault

Enable the Vault Database Secrets Engine at the path `campground-dbs`.

```bash
vault secrets enable -path=campground-dbs database
```

---

## Step 2: Configure PostgreSQL Connection

Next, set up the database connection in Vault. Use a consistent name like `my-postgresql-database`.

```bash
export DB_HOST=mattis
export DB_PORT=5432
export DB_NAME=mydatabase
export ROOT_DB_USER=postgres
export ROOT_DB_PASS=postgrespassword
vault write campground-dbs/config/my-postgresql-database \
    plugin_name=postgresql-database-plugin \
    allowed_roles="*" \
    connection_url="postgresql://{{username}}:{{password}}@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=disable" \
    username="$ROOT_DB_USER" \
    password="$ROOT_DB_PASS"
```

---

## Step 3: Create a Role for Credential Generation

Here, `db_name` should match the Vault database connection name (`my-postgresql-database`), **not** the PostgreSQL database name (`mydatabase`).

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

Generate a new set of credentials based on the `mydb-app` role.

```bash
vault read campground-dbs/creds/mydb-app
```

---

## Additional DB Types

Vault also supports other databases like MySQL, MongoDB, etc. The setup is similar; you just have to change the plugin name and connection parameters.
