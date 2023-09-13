# WiFi Setup Guide with Vault Secrets

After setting up your Vault server/container and logging in, follow this guide to store passwords or secrets in Vault.

A friendly reminder: While you'll see paths like "boterf24" or "boterfhome/wifi" in this guide, they're just examples. Feel free to craft your own paths that resonate with your setup. This is a guide to inspire and assist, not a strict blueprint to follow.

## Quick Setup Guide

### KV Version
You can now specify the version of the KV store you're using in Vault (`v1` or `v2`). Update the `kvVersion` option in your Nix configuration accordingly.

```nix
kvVersion = mkOption {
  type = enum ["v1" "v2"];
  default = "v1";
  description = "KV store version";
};
```

### Quick Setup Guide

If this is your first time, please do yourself a favor and go through the [In-Depth Setup](#in-depth-setup). This is more of a reference point rather than a set of detailed instructions.

1. **Create the KV Secret Engine and Store the WiFi Passwords**:
   ```bash
   vault secrets enable -path=boterfhome kv
   vault kv put boterfhome/wifi boterf24=secret_value boterf5=another_secret_value
   ```

2. **Define the Access Policy**:
   ```hcl
     path "boterfhome/*" {
       capabilities = ["read", "list"]
     }
   ```

3. **Apply the Policy and Set up AppRole Authentication**:
   ```bash
   vault policy write boterf-wifi-policy boterfhome_policy.hcl
   vault write auth/approle/role/boterf-wifi-role policies=boterf-wifi-policy
   ```

4. **Retrieve AppRole Credentials**:
   ```bash
   vault read -format=json auth/approle/role/boterf-wifi-role/role-id
   vault read -format=json auth/approle/role/boterf-wifi-role/secret-id
   ```

5. **Update Your Nix Configuration**:
   - Enable `wifi` in your Nix flake with the path: `boterfhome/wifi` and specify the networks you wish to connect to.
   - Enable the `vault-agent` in your Nix flake configuration. Set the `role-id` and `secret-id` paths according to where you securely stored them on your target machine. Specify the Vault server's HTTP URL.
   - **New**: Specify the `kvVersion` as either `v1` or `v2`.

---

## In-Depth Setup:

AppRoles are tied to access policies which grant access to secret engines.

1. **Create a Secret Engine**
   - Create a KV secret engine:
     ```shell
     vault secrets enable -path=boterfhome kv
     ```
   - Store the secrets in the engine:
     ```shell
     vault kv put boterfhome/wifi boterf24=secret boterf5=secret
     ```
   - Verify the secrets:
     ```shell
     vault kv get boterfhome/wifi
     ```

2. **Create or Adjust an Access Policy for the Secret Engine**
   - Create a local policy file (`boterfhome_policy.hcl`):
     ```hcl
     # Read capabilities for the data
     path "boterfhome/*" {
       capabilities = ["read", "list"]
     }
     ```
   - Use the `vault policy write` command:
     ```shell
     vault policy write boterf-wifi-policy boterfhome_policy.hcl
     ```

3. **Create and Assign an AppRole to the Access Policy**
   - Create an AppRole:
     ```shell
     vault write auth/approle/role/boterf-wifi-role
     ```
   - Associate the policy with the AppRole:
     ```shell
     vault write auth/approle/role/boterf-wifi-role policies=boterf-wifi-policy
     ```

4. **Retrieve the Role ID and Secret ID for the AppRole**
   - Get the Role ID:
     ```shell
     vault read auth/approle/role/boterf-wifi-role/role-id
     ```
   - Generate a new Secret ID:
     ```shell
     vault write -f auth/approle/role/boterf-wifi-role/secret-id
     ```

      **Important:** Once you've retrieved the `role-id` and `secret-id`, securely transfer and store them on your target machine. They should never be hard-coded in configuration files or exposed in any public manner.

   - Configuration of Nix System File:

      Ensure the following configuration sits under your respective system flake. For instance, within `systems/x86_64-linux/ata-xps-mboterf/default.nix`:

      ```nix
      wifi = {
        enable = true;
        vault-path = "boterfhome/wifi";
        networks = {
          boterf24 = {
            ssid = "Boterf-2.4G";
          };
          boterf5 = {
            ssid = "Boterf-5G";
          };
        };
      };
      ```

   - Vault Agent Configuration:

      Update the configuration with the `role-id` and `secret-id` you obtained earlier:

      ```nix
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "http://10.0.0.19:8200";
            role-id = "/path/to/on-target-machine/role_id";
            secret-id = "/path/to/on-target-machine/secret_id";
          };
        };
      };
      ```

      With these steps, you've created an AppRole in Vault, retrieved its `role-id` and `secret-id`, and updated your system's configuration to utilize these credentials to fetch secrets.
      ***Always ensure the `role-id` and `secret-id` are stored securely on the target machine and are not exposed.***

   > If you cannot access the secrets, check and double check login, then review/adjust the policy. Policy grants access to the kv secret engine and your app role is tied to a policy.

## Conclusion:

You've now set up a method to securely store, manage, and access secrets in Vault using KV version 1 or 2. Ensure that Role IDs, Secret IDs, and Vault tokens are handled securely. Rotate secrets periodically and monitor for unauthorized access.

