# LDAP Client Module for NixOS

This module provides LDAP client support for NixOS. It allows systems to enable LDAP users and configure LDAP support. It also includes a script to watch for new user directories in `/home` and create the necessary folders for LDAP users so they can use `home-manager`.

## Features

- Configurable LDAP support
- Domain name setting
- LDAP URI setting
- LDAP search base setting
- Credential caching
- Vault role-id and secret-id settings
- Vault address setting
- Trusted LDAP group setting
- Home directory creation for LDAP users
- LDAP user group for home-manager usage
- User directory watcher service

## Usage

To use this module, import it in your `./systems/x86_64-linux/<hostname>/default.nix` file and set the options according to your needs. Here is an example:

```nix
campground.services = {
    ldap-client = {
        enable = true;
        domain = "aicampground";
        ldap_uri = "ldap://ldap.campground.lan:389";
        ldap_search_base = "dc=aicampground,dc=com";
        cache_credentials = true;
        role-id = "/path/to/vault/role-id";
        secret-id = "/path/to/vault/secret-id";
        vault-address = "http://vault.campground.lan:8200";
        trusted_group = "ldap_user";
    };
};
```

## Options

- `enable`: Whether or not to configure LDAP support.
- `domain`: The domain name.
- `ldap_uri`: The LDAP URI to use.
- `ldap_search_base`: The LDAP search base.
- `cache_credentials`: Whether or not to cache credentials.
- `role-id`: Absolute path to the Vault role-id.
- `secret-id`: Absolute path to the Vault secret-id.
- `vault-address`: The address of your Vault.
- `trusted_group`: The LDAP Group of users who can use home-manager on the system.

