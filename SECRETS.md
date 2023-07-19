# How to use Hashicorp Vault to Manage Secrets on NixOS

The following is a guide describing how to securely provide secrets to a NixOS system.
This will assume you have a Hashicorp Vault server already running and configured.
This will also assume you have your NixOS configuration setup using [Snowfall-lib](https://github.com/snowfallorg/lib).
Credit goes to [Jake Hamilton](https://github.com/jakehamilton) for being the person
who actually came up with this method or was at least the person whom I am directly 
mimicking with my configuration.

## Create Policy

```hcl
path "secret/campground" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

```bash
vault policy write campground-policy campground_secrets.hcl
```

## Create an Authentication Method

Need to enable `approle` authentication.

```bash
vault auth enable approle
vault write auth/approle/role/campground-role policies=campground-policy
```


## Get the role ID and the Secret ID

These commands will output the role ID and secret ID, respectively. 
You'll need to provide these to your application, for example by writing 
them to the /role_id and /secret_id files as in the previous example.

```bash
vault read auth/approle/role/campground-role/role-id
vault write -f auth/approle/role/campground-role/secret-id
```

## Write the Secrets

```bash
vault kv put secret/campground value=my-super-secret-value
```

# How to use Vault Secrets in NixOS System

We are able to use the above secret in systemd services using [nixos-vault-service](https://github.com/determinatesystems/nixos-vault-service).
This `nixos-vault-service` does this by just patching systemd services. 

## Create Service

For the purpose of this example we need to create a service to use our secrets. In the 
context of how my dotfiles are configured (using [Snowfall-lib](https://github.com/snowfallorg/lib)),
we need to create a folder for our service in `./modules/services/<service-name>`. The service
is then defined with the following file.

*default.nix*

```nix
{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
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

## Enable Service

In side your system configuration file (`./systems/x86_64-linux/ata-xps`) you will need to enable the service. 
The following a excerpt from the system config to show what this would look like.

```nix
# ... more code ...

  campground.services = {
    secret-service = enabled;

# ... more services and code ...

  };

```

## Patch Services with Vault Secrets

To do this is pretty simple given you have the `vault-agent` service found at `./modules/services/vault-agent/default.nix`


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

Things to take note of in the above code block, `role_id_file_path` and `secret_id_file_path` are
files with just the token output from the above vault command. It is what the system uses to
authenticate with the Vault. These will need to be pre-deployed to your target system.

