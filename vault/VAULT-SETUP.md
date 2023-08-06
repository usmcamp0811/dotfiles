# How to Use Hashicorp Vault for Managing Secrets on NixOS

This guide will walk you through the process of securely providing secrets to a NixOS system using Hashicorp Vault. It assumes that you already have a Hashicorp Vault server up and running, and that your NixOS configuration is using [Snowfall-lib](https://github.com/snowfallorg/lib). The method described here is inspired by [Jake Hamilton](https://github.com/jakehamilton).

The rest of this documentation should allow you to create the necessary items within vault to prevent the leakage of secrets.

## Prerequisites

- [Install Vault](https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install "Install Vault")

Once installed You'll follow the following steps locally on your machine

1. Set `VAULT_ADDR` environment variable:

>The Vault CLI uses the VAULT_ADDR environment variable to know where the Vault server is located. Set this to the address of your server, in your case: http://<ip or local address>:8200.

If you're using a Unix-like operating system (like Linux or MacOS), you can do this in the terminal:

```sh
export VAULT_ADDR='http://10.0.0.19:8200'
```

This will set the environment variable for your current session. If you want to set it permanently, you'll need to add the command to your shell's profile script (like .bashrc, .bash_profile, or .zshrc for Unix-like systems).

1. Authenticate your client:

Before you can interact with the Vault server, you need to authenticate your client. The steps to do this will depend on which authentication method you've set up on your server.
If you're using the default "token" authentication method, you'll need the token that was generated when you initialized your Vault server. You can set it using the vault login command:

```sh
vault login
```

Once you run this command, you'll be prompted to input a token which you'll provide either the root or another token you've created. Once this step is done, you won't need to execute `vault login` again.

After these steps, you should be able to run commands like vault policy write from your local machine, and they will interact with your Vault server. Note that the specific commands you can run will depend on the policies and permissions associated with your authentication token.

Please remember, handling tokens securely is crucial because they provide access to your Vault instance. Avoid logging them or exposing them in your scripts or command lines.

## Creating a Policy

First, create a policy using the following code:

```hcl
path "secret/campground" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

Then, write the policy to the vault:

```bash
vault policy write campground-policy campground_secrets.hcl
```

## Setting Up an Authentication Method

Next, enable the `approle` authentication method and write the role:

```bash
vault auth enable approle
vault write auth/approle/role/campground-role policies=campground-policy
```

## Obtaining the Role ID and Secret ID

Use the following commands to obtain the role ID and secret ID:

```bash
vault read auth/approle/role/campground-role/role-id
vault write -f auth/approle/role/campground-role/secret-id
```

These IDs will be needed by your application. You can provide them by writing them to files which we'd encourage naming `role_id` and `secret_id` files. You may place them in any location on your file system, but we'd encourage `/var/lib/vault/<system>/`

> role_id goes into the role_id file and the secret_id goes into the secret_id file

commands:
```bash
mkdir -p /var/lib/vault/<system>
touch /var/lib/vault/ata-xps/role_id /var/lib/vault/ata-xps/secret_id
```

```sh
# in your default.nix system level config
    vault-agent = {
      enable = true;
      settings = {
        vault = {
          address = "https://<hostname/ip:port>";
          role-id = "/var/lib/vault/ata-xps/role-id";
          secret-id = "/var/lib/vault/ata-xps/secret-id";
        };
      };
    };
```

## Writing the Secrets

To write the secrets, use the following command:

```bash
vault secrets enable -path=secrets/campground kv
vault kv put secrets/campground/data value=my-super-secret-value
```


## How To Examples

[How-To Examples](./HOW-TO.md)


## Walk-through setting up WIFI for your system

[Wifi walkthrough](./WIFI-GUIDE.md)
