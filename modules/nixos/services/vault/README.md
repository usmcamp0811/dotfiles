---
type: NixOS Module
title: Vault NixOS Module
description: This module simplifies the configuration and management of HashiCorp Vault on NixOS.
resource: ./default.nix
tags: [services, vault]
---

# Vault NixOS Module

This module simplifies the configuration and management of HashiCorp Vault on NixOS. It supports features
like auto-unsealing, policy management, and integration with other services. Below is an explanation
of how to use the module with an example configuration.

---

## Key Features

- **UI Support**: Optionally enable Vault's web UI.
- **Storage Backends**: Supports `file` or `raft` storage backends with advanced configuration options.
- **Auto-Unseal**: Automatically unseal Vault using Clevis and Tang.
- **Policy Management**: Dynamically load and apply Vault policies from HCL files or inline configuration.
- **Integration**: Works seamlessly with other services like Vault Agent.

---

## Prerequisites

### For Auto-Unseal

If you enable the `auto-unseal` feature, ensure that:

1. Vault is initialized with a **single unseal key**:

   ```bash
   vault operator init -key-shares=1 -key-threshold=1
   ```

2. The unseal key is encrypted using Tang and stored in a path accessible to the configuration.

#### Encrypting the Unseal Key with Clevis and Tang

To secure your Vault unseal key with Clevis and Tang, follow these steps. This setup requires the key
to be unlocked using a TPM chip and at least 4 Tang servers.

1. **Store the unseal key in a file:**

   ```bash
   echo "your-unseal-key" > /var/lib/vault/unseal-key.txt
   chmod 600 /etc/vault/unseal-key.txt
   ```

2. **Encrypt the unseal key using Clevis and Tang:**

   ```bash
   clevis encrypt sss '{"t":4,"servers":["http://tang1:80","http://tang2:80","http://tang3:80","http://tang4:80"]}' \
   < /etc/vault/unseal-key.txt \
   > /etc/vault/unseal-key.enc
   ```

3. **Verify the encrypted key file:**

   ```bash
   clevis decrypt < /etc/vault/unseal-key.enc
   ```

   If the decryption works, the original unseal key should be displayed.

4. **Secure the original unseal key file (optional but recommended):**
   ```bash
   shred -u /etc/vault/unseal-key.txt
   ```

This configuration ensures the unseal key is secured with:

- **TPM-based security**: Uses the TPM chip on your machine.
- **Tang-based Shamir Secret Sharing (SSS)**: Requires a minimum of 4 Tang servers to decrypt the key.

Make sure to distribute the Tang servers across independent, secure systems to avoid a single point of failure.

---

## Example Configuration

Here’s how to configure the Vault module in your NixOS setup:

```nix
{ lib, ... }:
with lib;
with lib.campground;

{
  imports = [ ./hardware.nix ];

  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" ];
      uid = 10000;
    };

    services = {
      vault = {
        enable = true;
        ui = true;

        # Storage backend configuration
        storage = {
          backend = "raft";
          config = ''
            node_id = "vault-node-daly"
            retry_join {
              leader_api_addr = "http://chesty:8200"
            }
            retry_join {
              leader_api_addr = "http://lucas:8200"
            }
          '';
        };

        # Additional Vault settings
        settings = ''
          cluster_addr = "http://daly:8201"
          api_addr = "http://daly:8200"
        '';

        # Policies are dynamically loaded from the specified directory
        policies = builtins.foldl'
          (policies: file:
            policies // {
              "${snowfall.path.get-file-name-without-extension file}" = file;
            })
          { }
          (builtins.filter (snowfall.path.has-file-extension "hcl")
            (builtins.map
              (path:
                ./vault/policies + "/${
                builtins.baseNameOf (builtins.unsafeDiscardStringContext path)
              }")
              (snowfall.fs.get-files ./vault/policies)));
      };

      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "http://lucas:8200";
            role-id = "/var/lib/vault/daly/role-id";
            secret-id = "/var/lib/vault/daly/secret-id";
          };
        };
      };
    };
  };

  # This determines the NixOS release version.
  system.stateVersion = "23.05";
}
```

---

## Configuration Details

### Vault Options

| Option     | Description                                                |
| ---------- | ---------------------------------------------------------- |
| `enable`   | Enable or disable Vault.                                   |
| `ui`       | Enable or disable the Vault UI.                            |
| `storage`  | Configure the Vault storage backend (`file` or `raft`).    |
| `settings` | Additional runtime configuration for Vault.                |
| `policies` | Define Vault policies as inline HCL or paths to HCL files. |
| `mutable-policies` | When `false` (default), policies not declared in `policies` are deleted. |
| `approles` | Declare AppRoles by name: `{ <role> = { token_policies = [...]; settings = {...}; }; }`. See [AppRoles](#approles). |
| `prune-approles` | When `true`, AppRoles not declared in `approles` are **deleted**. Default `false` (report only). |

### Storage Configuration

- **Raft Backend**: Used for high-availability setups.
- **File Backend**: Simplified setup for single-node deployments.

---

## Notes on Policy Management

Policies can be dynamically loaded from a directory or defined inline. Example inline policy:

```nix
policies = {
  admin = ''
    path "sys/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  '';
};
```

---

## AppRoles

Policies are files; AppRoles used to be created by hand with `vault write auth/approle/role/...`,
so Vault was the only record of which roles exist. `approles` makes them declarative the same
way `policies` are:

```nix
fmf.services.vault.approles = {
  vm-media.token_policies = ["vm-media"];
  gitlab-runner = {
    token_policies = ["gitlab-runner"];
    settings.token_ttl = 180; # any AppRole role parameter, passed through verbatim
  };
};
```

The `vault-policies` service writes policies first, then each role (`vault write
auth/approle/role/<name> @<json>`), then compares Vault's role list with the declared one.

- **Not managed:** `role-id` and `secret-id`. Secret-ids must never enter the Nix store. Re-writing
  an existing role does not change its role-id or invalidate issued secret-ids.
- **Update semantics:** only the parameters you declare are written; a parameter you leave out keeps
  whatever value the role already has. Set a parameter explicitly if you want Nix to enforce it.
- **Undeclared roles** are logged as `UNMANAGED approle (exists in Vault, not declared in Nix): <name>`
  (`journalctl -u vault-policies`). They are only **deleted** with `prune-approles = true`, which
  immediately breaks any host still logging in with that role, including the role the policy agent
  itself uses. Turn it on last, after the audit is clean.
- With `approles = {}` (the default) none of this runs and the service behaves exactly as before.

The policy agent logs in as an AppRole with a policy that allows `auth/approle/role/*`. If it does
not (anything narrower than `admin`), the role writes fail and the service retries.

See [Vault AppRoles](../../../../docs/VAULT-APPROLES.md) for the naming convention, auditing, and the migration
plan.

---

## Troubleshooting

- **Auto-Unseal Issues**: Ensure the unseal key is correctly encrypted with Tang and accessible at the specified path.
- **Policy Errors**: Verify that the HCL files are correctly formatted and pass Vault's syntax checks.
- **Service Logs**: Use `journalctl -u vault` to view logs and debug service issues.
