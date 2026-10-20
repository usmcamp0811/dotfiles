---
type: NixOS Module
title: Home Assistant (fmf.services.home-assistant)
description: Runs the NixOS Home Assistant Core service, using fmf's usual enable/options wrapper and optional Vault Agent AppRole sidecar.
resource: ./default.nix
tags: [services, home-assistant]
---

# Home Assistant (`fmf.services.home-assistant`)

Runs the NixOS Home Assistant **Core** service, using fmf's usual enable/options
wrapper and optional Vault Agent AppRole sidecar. NixOS owns configuration and
packages; Home Assistant owns its users, dashboards and integration state.

This is **not Home Assistant OS or Supervised**: there is no Supervisor/add-on
store. Run MQTT, Zigbee2MQTT, ESPHome, etc. as separate NixOS services if needed.
Home Assistant upstream does not support this installation method; Nixpkgs
maintains the packaging and service. Do not update Core with pip or through the UI.

## Quick start

```nix
{
  fmf.services.home-assistant = {
    enable = true;
    openFirewall = true;
    config.homeassistant = {
      name = "Home";
      unit_system = "us_customary";
    };
  };
}
```

Open `http://<machine-ip>:8123` **from a trusted LAN**, immediately complete
onboarding and create the owner account. No bootstrap admin password, API token,
database password or Vault secret is required. Home Assistant stores the owner
account in its private state directory. Enable MFA in the user's profile.
Direct HTTP is unencrypted: use a trusted network, VPN, or a TLS reverse proxy.
Do not expose the onboarding endpoint or port 8123 to the internet.

## Options

All options below are under `fmf.services.home-assistant`.

| Option | Default | Purpose |
| --- | --- | --- |
| `enable` | `false` | Enable Core |
| `dataDir` | `/var/lib/hass` | Configuration, `.storage`, SQLite history, backups, UI YAML files |
| `port` | `8123` | HTTP port |
| `listenAddress` | `0.0.0.0` | Bind address |
| `openFirewall` | `false` | Open the HTTP port |
| `openFirewallForComponents` | `false` | Let the upstream module open its supported component ports |
| `extraComponents` | `[ "default_config" "esphome" "met" ]` | Install dependencies for integrations selected in the UI |
| `config` | `{}` | Additional declarative Home Assistant YAML settings |
| `trustedProxies` | `[]` | Explicit proxy IPs/CIDRs; enables forwarded client IP handling |
| `vault.enable` | `false` | Enable runtime `secrets.yaml` rendering |
| `vault-path` | `secret/campground/home-assistant` | Logical KV path |
| `kvVersion` | `"v2"` | `v1` or `v2` |
| `vault-address` | global Vault Agent address, otherwise `https://vault.lan.aicampground.com` | Vault endpoint |
| `role-id` | global role-id path, otherwise `/var/lib/vault/home-assistant/role-id` | AppRole credential file |
| `secret-id` | global secret-id path, otherwise `/var/lib/vault/home-assistant/secret-id` | AppRole credential file |

Defaults enable `default_config` and include mutable `automations.yaml`,
`scenes.yaml` and `scripts.yaml`. Missing files are initialized once, **not reset
on restart**. `configuration.yaml` itself is declarative and must be changed in
Nix. You can override the includes through `config` for declarative automations.

Use native `services.home-assistant` options for advanced features such as
`package`, `extraPackages`, `customComponents`, themes or Lovelace modules. The
wrapper retains the upstream `hass` user, systemd hardening and package defaults.

### Installing integrations

Integration dependencies are installed at build time, not fetched with pip.
An integration's URL slug is normally its component name. For example:

```nix
{
  fmf.services.home-assistant.extraComponents = [
    "default_config" "esphome" "met" "mqtt" "shelly"
  ];
}
```

Rebuild before adding those integrations in the UI. Use integration names
available in your pinned Nixpkgs; unsupported names fail module evaluation.
UI-managed integration credentials live in `.storage`, **not automatically in
Vault**. Protect and back up that directory as secret data.

### TLS reverse proxy

```nix
{
  fmf.services.home-assistant = {
    trustedProxies = [ "10.8.0.4" ];
    config.homeassistant = {
      external_url = "https://home-assistant.example.com";
      internal_url = "http://10.8.0.25:8123";
    };
  };
}
```

Configure the proxy separately and enable WebSocket forwarding. Trust only the
actual proxy addresses, never `0.0.0.0/0`. Keep Home Assistant's own authentication;
generic forward-auth middleware can break the companion app and API clients.

## Optional Vault secrets

Use Vault for integrations configured in YAML that support `!secret`. Do not put
passwords, tokens or private location data directly in `config`: generated Nix
configuration is readable in the Nix store.

```nix
{
  fmf.services.home-assistant = {
    enable = true;
    vault.enable = true;
    role-id = "/var/lib/vault/vm-home-assistant/role-id";
    secret-id = "/var/lib/vault/vm-home-assistant/secret-id";
    config.homeassistant = {
      latitude = "!secret latitude";
      longitude = "!secret longitude";
    };
  };
}
```

Every field of the configured Vault KV secret becomes a `secrets.yaml` key. The
sidecar renders the map as JSON (also valid YAML), so quotes and newlines in
credentials are safely encoded. It uses the existing `fmf.services.vault-agent`
integration: files are in shared PrivateTmp, owned by `hass`, mode `0600`.
`dataDir/secrets.yaml` is a symlink to that runtime file, not a persistent secret
copy. Initial rendering gates service startup; changes restart Home Assistant.
With Vault enabled, Vault availability is therefore a startup dependency.

### Provision KV v2 and AppRole

Run these with a Vault administrator/operator login on a trusted machine.
Set `VAULT_ADDR` to your Vault HTTPS endpoint and authenticate using your usual
method (`vault login`). The `secret/` KV v2 mount and `approle/` auth method are
assumed to exist already; do not recreate existing mounts.

Create a private JSON file **outside the repository**, for example with your
editor at `/tmp/home-assistant-secrets.json`, then `chmod 600` it. Its fields are
the names used by `!secret`, for example numeric `latitude` and `longitude` or
an integration-specific token. Upload the file without putting values in shell
history or process arguments:

```bash
vault kv put secret/campground/home-assistant @/tmp/home-assistant-secrets.json
```

`kv put` replaces the KV map: include all keys you need, or use `vault kv patch`
to change individual fields. The agent reads the logical path above; Vault's
KV v2 **policy** must instead authorize the `/data/` API path:

```hcl
# Save as /tmp/home-assistant-policy.hcl (contains no secret values).
path "secret/data/campground/home-assistant" {
  capabilities = ["read"]
}
```

```bash
vault policy write vm-home-assistant /tmp/home-assistant-policy.hcl
vault write auth/approle/role/vm-home-assistant \
  token_policies=vm-home-assistant token_ttl=1h token_max_ttl=24h \
  secret_id_ttl=0 secret_id_num_uses=0
```

Unlimited-use/non-expiring SecretIDs match unattended reboot requirements of the
current file-based pattern. Treat them as durable passwords: scope the policy
tightly, store as root-only files, and rotate/revoke deliberately.

To retrieve credentials without printing them, in **bash** on the machine where
the host credential directory will be provisioned:

```bash
umask 077
credentials=$(mktemp -d)
vault read -field=role_id auth/approle/role/vm-home-assistant/role-id > "$credentials/role-id"
vault write -f -field=secret_id auth/approle/role/vm-home-assistant/secret-id > "$credentials/secret-id"
sudo install -d -m 0700 /persist/system/var/lib/vault/vm-home-assistant
sudo install -m 0600 "$credentials/role-id" "$credentials/secret-id" \
  /persist/system/var/lib/vault/vm-home-assistant/
rm -f "$credentials/role-id" "$credentials/secret-id"
rmdir "$credentials"
```

In the Campground MicroVM, that host directory is shared to
`/var/lib/vault/vm-home-assistant`. For a physical host, install into your selected
`role-id`/`secret-id` paths instead. The AppRole authenticates **Vault Agent**;
it is not the Home Assistant owner account or a Home Assistant API token.
For KV v1 use `kvVersion = "v1"` and a policy on the logical secret path (no
`/data/` segment).

## State and backups

Persist **all** of `dataDir`, especially `.storage` (users/tokens/integrations),
`home-assistant_v2.db`, automation/scene/script YAML and backups. SQLite is the
default recorder; an external database is not required.

Stop Home Assistant before a filesystem copy or take an application-consistent
backup. Back up AppRole files separately if Vault is used. A filesystem snapshot
alone is not a tested restore strategy: test restoring into a disposable VM.
Rolling back the Nix generation does not undo database migrations; retain a
pre-upgrade data backup.

## Networking and hardware

Same-subnet discovery needs mDNS UDP 5353 and SSDP UDP 1900 as appropriate;
the Campground guest opens those ports. Discovery across VLANs requires router
multicast reflection and appropriate firewall policies, not just guest ports.
Device callbacks can require additional integration-specific inbound ports.

Bluetooth/Zigbee/Z-Wave USB devices are **not** automatically available inside a
MicroVM. Use network coordinators/proxies, or explicitly configure supported
device passthrough and guest permissions. Installing an integration dependency
does not pass through its hardware.

## Verification and troubleshooting

```bash
sudo systemctl status home-assistant.service --no-pager
sudo journalctl -u home-assistant.service -n 100 --no-pager
curl --fail --silent --show-error -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8123/
# Only when Vault is enabled:
sudo systemctl status detsys-vaultAgent-home-assistant.service --no-pager
sudo journalctl -u detsys-vaultAgent-home-assistant.service -n 100 --no-pager
```

- **Dependency/module missing:** add its name to `extraComponents` and rebuild.
- **Vault 403:** check AppRole policy and KV version; do not broaden to all secrets.
- **Secret not found:** ensure each `!secret` name exists in the selected KV map.
  The runtime file is in PrivateTmp and is not visible in the host's ordinary
  `/tmp`; don't debug by printing credentials to logs.
- **Permission denied:** the state directory must be owned by guest `hass:hass`
  (standard NixOS UID/GID 286). Virtiofs preserves numeric ownership.
- **Can't access from the VM host:** macvtap isolates guest and host. Test from
  another LAN machine, or intentionally change to bridged TAP networking.
- **No discovery:** check VLAN policies and multicast before changing packages.

See also [NixOS Home Assistant](https://wiki.nixos.org/wiki/Home_Assistant),
[Home Assistant configuration](https://www.home-assistant.io/docs/configuration/),
and [Home Assistant secrets](https://www.home-assistant.io/docs/configuration/secrets/).
