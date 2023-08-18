# Setup Wifi with VAULT and nixos

In this walkthrough we'll cover how to add your credentials to vault, and how to adjust your system default.nix

In short, we're going to go back to our configuration and add or adjust the following values like below.

```nix
      wifi = {
        enable = true;
        vault-path = "boterf_home/wifi"
        networks = {
          Boterf5 = {
            ssid = "Boterf-5G";
          };
          Boterf24 = {
            ssid = "Boterf-2.4G";
          };
        };
      };
```

```nix
  campground.services = {
    vault-agent = {
      enable = false;
      settings = {
        vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/ata-xps/role-id";     # These lines are what should be adjusted
          secret-id = "/var/lib/vault/ata-xps/secret-id";
        };
      };
    };
  };
```

In the first code block we have wifi `enable = true`. This going to allow us to pull the secrets for our wifi appropriately. At this point we need to upload these creds into our vault


In our wifi block we have our two network names: `Boterf5` for our 5Ghz Radio and `Boterf24` for our 2.4Ghz Radio. Those names are what needs to be included in our key value store in vault. In the next code block, I'll list out the commands you'll use to create the key values.

```shell
vault secrets enable -path=boterf_home/ kv
vault kv put boterf_home/wifi/ Boterf24="notPassword" Boterf5="notPassword"
```

Remember to `vault login` before running the commands if you aren't already logged into the vault.

This is just an example, and we hope that you'll create and alter the paths as you see fit.
