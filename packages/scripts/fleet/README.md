---
type: Reference
title: fleet (generate network files from host records)
description: Command that evaluates every host's fmf.host record and writes the DHCP leases, DNS names and router port forwards derived from them, or checks that the committed files are current.
tags: [fleet, hosts, network, dns]
status: draft
---

# fleet

Derives the network files of a flake from the `fmf.host` records of its hosts, so an address, a name or a
forwarded port is written once, on the host it belongs to, instead of in a lease file, a DNS map and a
forwards list that must be kept in step. The model is in [Host model](../../../docs/HOST-MODEL.md); the
options are in the [host record module](../../../modules/nixos/system/host/README.md).

**New to it?** Start with [Getting started](../../../docs/FLEET-GETTING-STARTED.md). The [runbook](../../../docs/FLEET-RUNBOOK.md)
has the day-to-day procedures and [troubleshooting](../../../docs/FLEET-TROUBLESHOOTING.md) explains each error
this command can print. `fleet` reads the flake through git, so a file you have not `git add`ed does not exist for it.

## Use

Run it from the root of the flake that defines your `nixosConfigurations`:

```bash
fleet                   # write network/generated/{leases,dns,forwards,microvms}.nix
fleet --check           # exit non-zero if the committed files are stale (for CI)
fleet --show vm-media   # what is derived for one host, writes nothing
```

From a downstream flake that has `fmf` as an input: `nix run --inputs-from . fmf#fleet -- --check`.
Defaults match Campground's layout; override with `--hosts-dir`, `--out`, `--device-leases`, `--flake`
(see `fleet --help`).

## What it produces

| File | Contents | Consumed by |
|---|---|---|
| `leases.nix` | `{ <zone> = [ { mac; ip; hostname; } ]; }`, one lease per host interface with a MAC and an address | the router's `dhcp.staticLeases`, merged with the device leases |
| `dns.nix` | `{ "<name>" = "<ip>"; }`: every host by its name and lease name, short and as `<name>.<zone hostDomain>`, plus every device the same way. Lower-case. | the DNS server's rewrites |
| `forwards.nix` | the router port forwards declared by hosts (`fmf.host.expose`) | the router's `portForwards`, merged with the hand-kept ones |
| `microvms.nix` | per hypervisor, the `microvm.vms` flags, directories (tmpfiles) and start ordering of every VM that sets `fmf.host.derive` | a hypervisor reads its own entry; the VM adds its `flake` |

Hosts that are `retired` produce nothing; `standby` hosts get leases and names but no forwards.

**What stays hand-kept.** Machines that are not hosts (iot devices, cameras, access points, switches) keep
their own lease files (`<zone>-leases.nix`, one per zone, found by `--device-leases`). They are not part of
the generated leases, but they take part in DNS and in the clash checks: a device that shares an address or
MAC with a host is an error. Service names and wildcards, and forwards to addresses that are not hosts (for
example Kubernetes load balancers), also stay in their own files.

## How it works

The rules live in [`lib/fleet`](../../../lib/fleet/default.nix) (`lib.fmf.fleet`), pure Nix with tests. This
command evaluates each host once (`fleet.extract`, about ten seconds and half a gigabyte per host; a few
hosts in parallel, retried because concurrent evaluations occasionally trip over Nix's cache), then renders
all four files in one pass. It **refuses to write while the fleet has errors** (duplicate address or MAC, a
host placed on a retired one, a name that resolves to two addresses, ...) and prints warnings.

A downstream repository should also run the same derivation as a flake check (Campground:
`checks/fleet`) so a record or a generated file that was edited without regenerating fails the build.
