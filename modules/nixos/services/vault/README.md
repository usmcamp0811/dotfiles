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

## Troubleshooting

- **Auto-Unseal Issues**: Ensure the unseal key is correctly encrypted with Tang and accessible at the specified path.
- **Policy Errors**: Verify that the HCL files are correctly formatted and pass Vault's syntax checks.
- **Service Logs**: Use `journalctl -u vault` to view logs and debug service issues.
