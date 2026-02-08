# How to Use Hashicorp Vault for Managing Secrets on NixOS

This guide will walk you through the process of securely providing secrets to a NixOS system using Hashicorp Vault. It assumes that you already have a Hashicorp Vault server up and running, and that your NixOS configuration is set up using [Snowfall-lib](https://github.com/snowfallorg/lib). The method described here is inspired by [Jake Hamilton](https://github.com/jakehamilton).

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

These IDs will be needed by your application. You can provide them by writing them to the /role_id and /secret_id files.

## Writing the Secrets

To write the secrets, use the following command:

```bash
vault kv put secret/campground value=my-super-secret-value
```

# Using Vault Secrets in a NixOS System

You can use the secrets in systemd services with the help of [nixos-vault-service](https://github.com/determinatesystems/nixos-vault-service), which patches systemd services.

## Creating a Service

For this example, we'll create a service to use our secrets. In the context of how my dotfiles are configured (using [Snowfall-lib](https://github.com/snowfallorg/lib)), we need to create a folder for our service in `./modules/services/<service-name>`. The service is then defined with the following file:

*default.nix*

```nix
{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.services.secret-service;
in
{
  options.campground.services.secret-service = with types; {
    enable = mkBoolOpt false "Whether or not to enable secret-service.";
  };

  config = mkIf cfg.enable {
    systemd.services."secret-service" = {
      description = "My Secret Service!";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c 'for i in {1..5}; do echo $YANKEE_WHITE; sleep 1; done'";
        Type = "oneshot";
      };
    };
  };
}
```

## Enabling the Service

To enable the service, you need to modify your system configuration file (`./systems/x86_64-linux/ata-xps`). Here's an excerpt from the system config showing how to do this:

```nix
# ... more code ...

  campground.services = {
    secret-service = enabled;

# ... more services and code ...

  };

```

## Patching Services with Vault Secrets

To patch services with Vault secrets, you need to have the `vault-agent` service found at `./modules/services/vault-agent/default.nix`. Here's how to do it:

```nix
# ... more code ...
  campground.services = {
    secret-service = enabled;
    vault-agent = {
      enable = true;

      services = {
        "secret-service" = {
          settings = {       # replace with the address of your vault
            vault.address = "https://vault.lan.aicampground.com";

            auto_auth = {
              method = [{
                type = "approle";

                config = {
                  role_id_file_path = "/var/lib/vault/secret-service/role-id";
                  secret_id_file_path = "/var/lib/vault/secret-service/secret-id";

                  remove_secret_id_file_after_reading = false;
                };
              }];
            };
          };
          secrets.environment.templates = {
            secret-service-env = {
              text = ''
                {{ with secret "secret/campground" }}
                YANKEE_WHITE="{{ .Data.value }}"
                {{ end }}
              '';
            };
          };
        };
      };
    };

# ... more services and code ...
```

Please note that `role_id_file_path` and `secret_id_file_path` are files containing the token output from the above vault command. The system uses these to authenticate with the Vault. These files need to be pre-deployed to your target system.

**Additional Notes as I learn things:**
- Keys in KV secrets probably should not contain `.` in them else you might have a hard time putting them into variables or files.
