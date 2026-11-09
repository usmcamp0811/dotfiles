---
type: NixOS Module
title: Host record (fmf.host)
description: One per-machine declaration (kind, lifecycle, interfaces and zones, MicroVM placement and storage, boot order, DNS, exposure, Vault, topology) read by lib.fmf.fleet; declares data only.
resource: ./default.nix
tags: [system, host, fleet, network, microvm]
status: draft
---

# Host record (`fmf.host`)

Describes a machine once, in its own system configuration, so leases, DNS, port forwards, Vault roles,
MicroVM hosting and boot order can be derived from the whole fleet instead of being written in several
places. The design, decisions and verification results are in [Host model](../../../../docs/HOST-MODEL.md).

**This module only declares data.** Setting it has no effect on the machine. The fleet function
`lib.fmf.fleet` (in `lib/fleet`) reads the records of every host and produces the derived data; consumers
are added phase by phase. A host with `kind = null` (the default) is not managed and is ignored.

## Example

```nix
# a zone catalogue, set once in a module every host imports
fmf.network.zones.lan = {
  subnet = "192.168.50.0/24";
  gateway = "192.168.50.1";
  dns = ["192.168.50.2"];
  hostDomain = "lan-hosts.aicampground.com";  # host names; keep apart from service names
};

# a MicroVM
fmf.host = {
  kind = "microvm";
  network.interfaces.lan = { mac = "02:00:00:00:00:b0"; ip = "192.168.50.16"; zone = "lan"; };
  placement.runsOn = "lucas";
  storage = {
    mattermost = { mountPoint = "/var/lib/mattermost"; tag = "mattermost-data"; };
    postgresql = { mountPoint = "/var/lib/postgresql"; };
  };
  expose = [ { port = 8443; proto = "udp"; description = "Mattermost Calls"; } ];
};

# a physical host on two networks
fmf.host = {
  kind = "physical";
  network.interfaces = {
    eth  = { mac = "e0:d5:5e:29:11:a9"; ip = "192.168.50.189"; zone = "lan"; primary = true; };
    wifi = { mac = "e0:d5:5e:29:11:a8"; ip = "192.168.50.188"; zone = "lan"; };
  };
};

# a retired host: nothing is generated for it, and references to it are errors
fmf.host = { kind = "physical"; lifecycle = "retired"; retired.reason = "permanently offline"; };
```

## Options

| Option | Meaning |
|---|---|
| `kind` | `physical`, `microvm`, or `null` (not managed). |
| `lifecycle` | `active`, `standby` (provisioned, not started, nothing exposed), `retired` (nothing generated). |
| `network.interfaces.<n>` | `mac`, `ip` (null = dynamic), `zone`, `attach` (`tap`/`macvtap`), `static` (default true for a MicroVM), `primary` (needed when there is more than one), `leaseName`, `id` (MicroVM: its name on the hypervisor, at most 15 characters; default the host name for the primary or only interface, `<host>-<interface>` otherwise). |
| `hypervisor.networks.<zone>` | Physical hosts that run MicroVMs: how a guest interface in that zone is attached, `bridge = "br0"` (taps) or `macvtap = { link; mode; }`. Exactly one of the two. Empty = not described; nothing is checked. |
| `hypervisor.tapRules` | Default false. Generate one networkd rule per tap of each derived guest, joining it to its zone's bridge (written to `microvms.nix` by `fleet`). Turn it on one hypervisor at a time. |
| `placement` | `runsOn` (the hypervisor), `autostart`, `restartIfChanged` (default unset, so a VM that must not restart, like the Vault VM, keeps not restarting), `hostDirectories` (`managed`, or `external` when the directories already exist and must not be reset). |
| `derive` | MicroVM only, default false. The VM takes its shares and store overlay from this record, and its hypervisor generates its stanza, directories and ordering (`network/generated/microvms.nix`). Convert one VM at a time. |
| `nixStore` | `persistent` (default: `rw-store` share and overlay), `volatile` (overlay, no share) or `none`. |
| `standardShares` | `rootPassword` (default true) and `vaultAgent` (default: follows `fmf.services.vault-agent.enable`). |
| `storage.<n>` | `mountPoint`, `hostPath`, `tag`, `mode`, `owner`, `group`, `createDirectory` (false for a path that already exists and must not be reset), `readOnly`, `shared`, `order`. One entry is both the guest share and the host directory. The standard shares come first in a fixed order, then these by `order`. |
| `boot` | `after` (VMs on the same hypervisor), `hostUnits` (units on the hypervisor). |
| `dns` | `names` (extra names), `addAliases`. |
| `expose` | Router port forwards to the host's primary address. |
| `vault` | `role` (default: host name), `extraPolicies` (never the derived `svc-*` ones), `aliases` (legacy role names). |
| `topology` | `role`, `location`, `rack`, `tags`; feeds Circuit Breaker hints. |
| `fmf.network.zones.<id>` | `subnet`, `gateway`, `vlanId`, `dhcpRange` (`start`, `end`), `dns`, `hostDomain` (domain for host names, kept apart from service names), `description`. |

## Checks

`lib.fmf.fleet.mk` returns `errors` and `warnings` for the whole fleet: duplicate address or MAC, an address
outside its zone, an unknown zone, an active MicroVM without `runsOn` or placed on something that is not an
active physical host, boot ordering across machines or in a cycle, references to retired hosts, two hosts claiming
one Vault role or alias, two VMs claiming one storage path, and DNS names that would resolve to two addresses.
Warnings: a static address inside the DHCP pool that no lease reserves, a DHCP interface without a MAC, a host
with no interface. The bare host name resolves to the primary interface only.
Tests: `lib/fleet/tests.nix`.
