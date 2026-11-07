---
type: Design
title: Host model - one record per machine (draft spec)
description: A single per-host module (identity, interfaces, lifecycle, placement, storage, boot order, DNS, exposure, Vault, topology) and a fleet function that derives leases, DNS, port forwards, Vault roles, MicroVM hosting and boot ordering from it.
tags: [fleet, hosts, microvm, network, vault, design]
status: draft
---

# Host model: one record per machine

**Status: draft specification. Nothing in this document is implemented.** It records what was agreed in
discussion and what the repositories look like today, so the build can be reviewed against it. Open
questions are collected in [Open questions](#open-questions); phases and their verification gates are in
[Phasing](#phasing-and-verification).

## Problem

Onboarding or changing a machine means editing several unrelated places, and they drift. The evidence
below was read from the Campground and fmf repositories while this was written.

| Fact about a host | Where it lives today |
|---|---|
| IP and MAC | `blue-ridge/router/*-leases.nix`: 69 leases in five files (lan 34, iot 18, k8s 9, wifi 7, guest 1) |
| The same MAC | Again in each MicroVM's own `microvm.interfaces` (31 VMs) |
| A static IP | Sometimes in the VM itself, overriding its lease (`vm-pub-traefik`) |
| Name to address records | Hand-typed `lanHosts` in `vm-adguard`, the 17 entries in `port-forwards.nix`, `trustedProxyCidrs` in `reckless`, Traefik backends |
| Vault role and policies | `approles.nix`; the template-derived part is already generated |
| Vault credential directory | A `tmpfiles` line on the hypervisor **and** a virtiofs share in the VM, written twice |
| Where a VM runs | The hypervisor's `microvm.vms.<vm>` stanza, which the VM itself does not know about |
| A VM's data directories | `tmpfiles` lines on the hypervisor (about four per VM) **and** matching `microvm.shares` in the VM |
| Start-up order | Hand-written `after`/`wants` on `microvm@<vm>` units, per hypervisor |
| Topology | `fmf.services.circuit-breaker.hints`, separately |

Drift that already happened:

- **Duplicate addresses.** `edson` and `vm-pub-traefik` both had `10.8.0.20`. `authentik` and
  `vm-k8s-control-0` both have MAC `02:00:00:00:00:50`.
- **A stale lease.** `vm-pub-traefik` runs statically on `10.8.0.20` while its lease said `10.8.0.5`.
- **A dead host still provisioned.** `edson` is permanently offline but kept a lease, a Vault role with
  live secret-ids, and a place in the flake.
- **A silent lock-out risk.** An IP binding derived from the stale lease would have locked a working
  VM out.

## Goals and non-goals

**Goals**

1. Onboarding a machine means filling out one module in its own system configuration.
2. Everything else (leases, DNS, port forwards, Vault roles, MicroVM hosting, boot order, topology) is
   derived from those records by one function.
3. Contradictions (duplicate IP or MAC, a reference to a retired host, a boot-order cycle) fail the
   build instead of being discovered on the network.
4. A host that is retired stops being provisioned everywhere at once.
5. Migration is checked mechanically: the new derivation must reproduce the old files before they are
   deleted.

**Non-goals**

- Application configuration, secrets, or per-service settings.
- VM sizing (`vcpu`, `mem`) and the guest's own services; those stay in the VM's configuration.
- Vault policy derivation itself, which already exists (`vault-access`). This model supplies its
  inputs (role name, extras, expected addresses) and consumes its results.
- Enforcing IP binding. This model supplies the expected addresses it needs.

## Shape

```
  systems/<host>/default.nix                        fleet function                    consumers
 ┌───────────────────────────┐   nixosConfigurations   ┌───────────────────┐
 │ fmf.host = { ... }        │ ──────────────────────▶ │ lib.fmf.fleet     │ ──▶ router leases (per zone)
 └───────────────────────────┘                          │  (pure Nix, lazy) │ ──▶ DNS rewrites (AdGuard)
   one record per machine                               │                   │ ──▶ port forwards
   (plus fmf.host.devices for                           │  + assertions     │ ──▶ Vault roles + expected IPs
    non-NixOS appliances)                               └───────────────────┘ ──▶ per-hypervisor MicroVM hosting
                                                                                ──▶ boot-order units
                                                                                ──▶ circuit-breaker hints
```

The module only declares data and a few local effects. The fleet function is the same pattern the
Circuit Breaker inventory (`lib.fmf.circuitBreaker.mkInventory`) already uses: it takes
`nixosConfigurations` and reads each host through explicit accessors.

Placement of the code: the module, the fleet function and the Vault parts live in **fmf**. The consumers
that only Campground has (router zones and leases, the AdGuard instance, port forwards) are wired in
Campground.

## The host record (`fmf.host`)

Option names are provisional; the structure is what matters.

### Identity and lifecycle

| Option | Meaning |
|---|---|
| `kind` | `physical`, `microvm` (required). |
| `lifecycle` | `active` (default), `standby`, or `retired`. See below. |
| `retired.{since,reason,replacedBy}` | Documentation for a retired host; shown in reports. |

`lifecycle` semantics:

- **`active`**: everything is generated.
- **`standby`**: provisioned (lease, role, DNS, placement exist) but not started: `autostart = false`,
  no port forwards, and the Vault audit does not expect it to connect. For machines such as the standby
  `vm-topology`.
- **`retired`**: **nothing is generated.** No lease, no DNS, no forward, no Vault role (a role still in
  Vault is reported for deletion), no placement. The host may stay in `systems/` as a record, and it
  must still evaluate. Any other host that still references it (`boot.after`, DNS, `runsOn`, an
  expose target) is a build error.

### Network: more than one interface, and VLANs

```nix
fmf.host.network.interfaces.<name> = {
  mac  = "02:00:00:00:00:b0";
  ip   = "10.8.0.16";     # null = dynamic; no lease is generated and nothing is expected
  zone = "lan";           # selects subnet, VLAN, gateway and DHCP pool
  static = false;         # true: the host configures the address itself (the vm-pub-traefik case)
  attach = "tap";         # microvm only: tap | macvtap
};
```

- **Zones are defined once, fleet-wide** (name, `subnet`, `gateway`, `vlanId`, DHCP range), and
  interfaces refer to them by name. A VLAN is a zone with a `vlanId`; an interface does not carry its
  own tag. Today these live in blue-ridge's `fmf.router.zones`; they must be reachable by the fleet
  function, either by reading them from that configuration or by moving the catalogue to a shared
  place (open question).
- **Several interfaces** are the normal case: `lucas` has eth and wifi leases; a `vm-netobs`-style VM
  has one interface per monitored VLAN. Each interface produces its own lease and address. For Vault,
  the expected address set of a host is the union over its interfaces.
- **`static = true`** means the module configures the address in the guest (systemd-networkd) from the
  same record, so the lease and the machine cannot disagree. A generated lease is still produced so the
  address stays reserved and the audit knows it. Whether VMs should default to static is an open question.

### Placement and hosting a MicroVM

Declared **on the VM**, with the hypervisor deriving its side:

```nix
fmf.host.placement = {
  runsOn = "lucas";            # the hypervisor's host name
  autostart = true;
  restartIfChanged = true;
};
```

For each VM whose `runsOn` is a hypervisor, the fleet function produces for that hypervisor:

1. the `microvm.vms.<vm>` stanza (`flake`, `autostart`, `restartIfChanged`);
2. the per-VM directories (see Storage), including the Vault credential directory
   `/persist/system/var/lib/vault/<vm>` (mode 0700), which today is a hand-written `tmpfiles` line;
3. the standard shares (below) as `microvm.shares` in the guest;
4. ordering units (see Boot order);
5. the network attachment (see below).

**Standard shares**, always present unless opted out: `ro-store` (the host `/nix/store`), `vault-agent`
(credentials, when the guest runs vault-agent), `ssh-host-keys`, `root-password`, and the writable store
overlay (`/persist/vm-stores/<vm>/nix-store`) when the VM uses one. These are identical in every VM today
and are the main source of copy-paste.

**Network attachment is not uniform today, and is the highest-risk part.** Each hypervisor wires taps to
bridges by hand: blue-ridge matches `vm-*` onto `br-lan` and sends the netobs taps to VLAN bridges; lucas
builds `br0` over `eno1`, a VLAN `br0.40` on a separate `br-k8s` bridge, and trusts them in its firewall;
chesty has no bridge and uses macvtap on `enp7s0`. The model proposes a per-hypervisor map from zone to
attachment, declared once on the hypervisor:

```nix
fmf.host.hypervisor.networks.<zone> = { bridge = "br0"; };            # taps join this bridge
fmf.host.hypervisor.networks.<zone> = { macvtap.link = "enp7s0"; };   # or macvtap on a NIC
```

A VM's interface on zone X is then attached by looking up X on its hypervisor. **This is deliberately a
later phase** (see Phasing); until then the bridges stay hand-written and only the uniform parts above
are derived.

### Storage

Declared once on the VM; it produces the guest share **and** the host directory, which are written twice
today and can drift:

```nix
fmf.host.storage.<name> = {
  mountPoint = "/var/lib/mealie";                   # in the guest
  hostPath   = null;      # default: /persist/vm-data/<vm>/<name>
  mode       = "0755";    # host directory mode (ssh keys use 0700)
  readOnly   = false;
};
```

- The virtiofs tag defaults to the name; the host directory is created by `tmpfiles` with the given mode.
- A shared host path (the PostgreSQL backups share, `/persist/postgresqlBackups/<app>`) is a storage entry
  with `hostPath` set, so it is still declared in one place.
- **Assertion:** two VMs must not claim the same `hostPath` unless both mark it shared.

### Boot order

Start-up order must be explicit because it is what fails after a power loss (the router, tang, then
Vault, then everything that needs Vault).

```nix
fmf.host.boot = {
  after = [ "vm-vault" ];        # host names this one must start after
  hostUnits = [ ];               # extra units on the hypervisor (e.g. tang.socket)
  waitFor = [ ];                 # { host; port; timeout } for dependencies on another machine
};
```

- **Derived defaults.** A VM that runs `fmf.services.vault-agent` and is **co-located** with the Vault VM
  gets `after = [ vaultHost ]` automatically. The Vault VM gets `hostUnits = [ "tang.socket" ... ]`, which
  is what blue-ridge writes by hand now. Today blue-ridge lists four VMs after `vm-vault`; those four lines
  become unnecessary.
- **Ordering across machines is not expressible in systemd.** `After=` only orders units on one machine.
  The VMs on lucas that need Vault (which runs on blue-ridge) cannot be ordered after it; today they rely
  on vault-agent retrying (not verified here). The model therefore treats a `boot.after` that points at a
  host on a different hypervisor as a **build error**, and offers `waitFor`: a bounded, host-side wait
  (`ExecStartPre`) for a TCP port. A bounded wait is the safe form, since an unbounded one would hang a
  boot on a dependency that is down.
- **Assertions:** a cycle in `after` is an error; an `after` that names a retired host is an error.
- `standby` hosts do not appear in anyone's order.

### DNS

```nix
fmf.host.dns = {
  names = [ "mattermost.lan.aicampground.com" ];   # extra names for this host
  addAliases = true;                                # short name and <name>.<zone domain>
};
```

Every active host gets records for its short name and its FQDN per interface address, which replaces the
hand-typed `lanHosts` map in `vm-adguard` (today it contains both `vault` and `vm-vault`, and
`pub-traefik` and `vm-pub-traefik`, as separate entries that must be kept in step). `names` adds service
names. Wildcards such as `*.lan.aicampground.com -> LAN Traefik` stay a hand-kept fleet-level setting;
they are a property of the proxy, not of one host. A retired host produces no records.

### Exposure

```nix
fmf.host.expose = [ { port = 8443; proto = "udp"; description = "Mattermost Calls"; } ];
```

Each entry becomes a router port forward to the host's primary address, replacing the hand-typed
`destination` addresses in `port-forwards.nix`. It must name a port the host is actually configured to
listen on where that can be checked; otherwise it is documentation. A retired or standby host exposes
nothing.

### Vault

```nix
fmf.host.vault = {
  role          = "vm-mattermost";   # default: the host name
  extraPolicies = [ ];               # only what vault-agent templates cannot imply
  aliases       = [ ];               # legacy role names still used by this host
};
```

- **Policies are derived, not listed.** The `svc-*` policies already come from the vault-agent templates;
  the host record never repeats them. `extraPolicies` is for access with no template behind it (CLI or
  script access, the policy agent, a service account such as `gitlab-runner`).
- **`aliases`** make legacy names explicit (`lan-traefik`, `adguard`, `ata-nuc`). Each alias is a role
  that keeps working and carries the same policies and expected addresses, and each is a visible item to
  retire.
- `approles.nix` shrinks to the roles that belong to no host (service accounts, the policy agent's own
  role if kept separate).
- The credential directory on the hypervisor and the `vault-agent` share come from Placement; nobody
  writes them by hand.
- Expected source addresses (today `host-ips.nix` plus `expected-ips.nix`) are the host's interface
  addresses, so the override file goes away.
- Role cleanup follows `lifecycle`: a retired host's role is reported for deletion, and with
  `prune-approles` it is removed.

### Topology

```nix
fmf.host.topology = { role = "hypervisor"; location = "..."; rack = "..."; tags = [ ]; };
```

These feed `fmf.services.circuit-breaker.hints` with `mkDefault`, so existing hints keep winning and
nothing is declared twice. Addresses, MACs and placement need no entry: the inventory already reads them
from the evaluated configuration.

### Non-NixOS devices

Leases also cover machines that have no NixOS configuration at all: the iot zone (18), wifi (7), guest,
`pikvm`, access points and switches. A host record cannot describe them. They are declared as
`fmf.host.devices.<name>` on the machine that manages them (typically the router), with the same
interface fields, and appear in the generated leases, DNS and topology. Circuit Breaker already has a
`hints.devices` option for the same purpose; whether to reuse it or have one shared declaration is an open
question.

## The fleet function

`lib.fmf.fleet.mk { nixosConfigurations; zones; }` returns pure data:

| Output | Used for |
|---|---|
| `hosts`, with `active` / `standby` / `retired` partitions | everything below |
| `leases.<zone>` | the router's `dhcp.staticLeases`, replacing the five lease files |
| `dns.rewrites` | the AdGuard rewrites, replacing `lanHosts` |
| `forwards` | the router port forwards |
| `vault.{roles, expectedIps, aliases}` | `approles` and the IP audit |
| `hypervisors.<host>.{vms, directories, shares, units}` | the MicroVM hosting a hypervisor needs |
| `bootGraph` | ordering units and the cycle check |
| `assertions` | the fleet-wide checks below |

It is lazy and defensive in the same way as the Circuit Breaker exporter: each datum is read through an
accessor, and a host that cannot be read degrades to a diagnostic and not a crash of the whole fleet.

## Fleet-wide assertions

Failing the build, not warning, is the goal; the first phase may use warnings so the existing
contradictions can be fixed one at a time.

- Duplicate IP within a zone, duplicate MAC anywhere.
- An interface address outside its zone's subnet; an unknown zone.
- A MicroVM with no `runsOn`, or whose `runsOn` is not a physical host or is retired.
- A `boot.after` cycle, or one that crosses hypervisors.
- A reference to a retired host from anywhere.
- Two hosts claiming the same Vault role or alias.
- Two VMs claiming the same non-shared storage `hostPath`.
- A MicroVM MAC that is not locally administered (`02:...`).
- Warning: a static address inside the DHCP pool without a lease.

Today's contradictions (the authentik MAC clash is the live one) would be reported by the first run.

## What replaces what

| Today | After |
|---|---|
| `blue-ridge/router/*-leases.nix` | generated from `leases` |
| `vm-adguard` `lanHosts` | generated from `dns.rewrites` |
| `port-forwards.nix` destinations | generated from `forwards` |
| `approles.nix` explicit host roles, `generated/host-ips.nix`, `expected-ips.nix` | derived from `vault` |
| Per-hypervisor `microvm.vms.*`, per-VM `tmpfiles`, `microvm.shares` boilerplate | derived from placement and storage |
| `systemd.services."microvm@..."` ordering on blue-ridge | derived from boot order |
| Hand-set circuit-breaker role, location, tags | `topology` |

## Phasing and verification

Each phase has a gate that must pass before anything is deleted. The pattern is the one used when the
policy derivation was introduced: derive the new result, prove it equals the old files, then switch.

**Phase 0: the module and the checks, no consumers.**
Add the options and the fleet function. Fill in three pilot hosts (a physical host with two interfaces, a
MicroVM, a host with a legacy alias). Assertions run as warnings. *Gate:* the pilots evaluate; the fleet
function runs over all 44 configurations, and its **evaluation cost is measured** (see below) before going
further.

**Phase 1: identity, addresses, lifecycle, DNS, Vault.**
Generate the leases, the DNS rewrites and the Vault role and expected-IP maps. A one-shot import writes
the first `fmf.host` blocks from the existing lease files and role data; blocks are not hand-written for
44 hosts. *Gate:* the generated leases, rewrites and role map equal the files they replace (a set
comparison, since order is not meaningful), checked by a flake check. *Risk:* a wrong lease can take
machines off the network. Deploy blue-ridge only after the comparison is exact, and keep the previous
generation.

**Phase 2: exposure and topology.**
Generated port forwards and circuit-breaker hints. *Gate:* forwards equal today's list; the Circuit
Breaker inventory is unchanged.

**Phase 3: placement, storage and boot order (the uniform parts).**
Derive `microvm.vms`, directories, standard and per-VM shares, the credential directory and same-host
ordering. *Gate:* for every VM, the evaluated `microvm.shares` and the host's `tmpfiles` and ordering
equal the hand-written ones, including share order. **This is not cosmetic:** with `restartIfChanged`, a
different share list changes the VM's runner and the VM restarts on deploy, and restarting `vm-vault`
seals Vault. Do the hypervisors one at a time, non-critical first, and blue-ridge last.

**Phase 4: network attachment.**
The per-hypervisor zone-to-bridge map. This is the least uniform part and the easiest to get wrong
(bridge netfilter, `rp_filter`, trusted interfaces, VLAN bridges, macvtap). It may be left hand-written if
phase 3 delivers most of the value. Do it only with a recovery path to each hypervisor that does not rely
on the network being changed.

## Evaluation cost

The router reading the whole fleet makes its build evaluate every host. For scale, the Vault-agent
extraction over all 44 hosts in one process took about 69 seconds and 3.7 GB; the host record is a small
slice and should be much cheaper, but **that has not been measured**. If it is too heavy for a build, the
fallback is committed generated files plus a drift check, as the Vault policies already work. Phase 0
decides this by measurement.

## Open questions

1. **Namespace.** `fmf.host` (generic, shared) versus `campground.host`. Recommendation: `fmf.host`, with
   Campground-only consumers wired downstream.
2. **Lifecycle names.** `active`, `standby`, `retired` are proposed; the earlier suggestions were
   archive, inventory and obe. Is `standby` the right third state?
3. **Static or DHCP for VMs.** Static removes the dependency on a router deploy, which is what bit
   `vm-pub-traefik`, but moves network configuration into every guest.
4. **Cross-machine ordering.** Is a bounded `waitFor` acceptable, or should cross-host dependencies stay
   a convention?
5. **Where the zone catalogue lives.** Read from blue-ridge's router configuration, or moved to a shared
   fleet definition?
6. **Non-NixOS devices.** One shared declaration with Circuit Breaker's `hints.devices`, or separate?
7. **Retiring a host.** Is leaving it in `systems/` as a record right, or should retirement remove the
   directory once nothing references it?
8. **`restartIfChanged` for `vm-vault`.** It is commented out today on purpose. The placement default
   must preserve that choice per VM, not flip it.

## Risks, stated plainly

- **Network lock-out.** Leases and bridges are how machines reach each other. Phases 1 and 4 can take
  machines offline; the gates and one-at-a-time deploys are the mitigation, not a guarantee.
- **VM restarts on deploy.** Any change to a VM's runner restarts it. For Vault this means sealing and an
  outage for everything that reads secrets.
- **One more place to be wrong.** A mistaken record now propagates to the router, DNS and Vault together.
  The assertions and the equality gates exist to stop that before deployment.
- **Evaluation weight.** Unmeasured; see above.

## Evidence this was written from

Counts and file contents were read directly from the repositories on 2026-11-07: the lease files, the
`microvm.vms` stanzas and `tmpfiles` lines on blue-ridge, lucas and chesty, `vm-mealie`'s shares, the
blue-ridge ordering block, the AdGuard `lanHosts` map, the router zone definitions, and fmf's Circuit
Breaker hints. Per-hypervisor VM counts (blue-ridge about 6, chesty and lucas about 4, sledge and webb 2,
butler and ermy 1) come from a pattern match and are approximate. Nothing here has been run.
