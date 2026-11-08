---
type: Design
title: Host model - one record per machine (draft spec)
description: A single per-host module (identity, interfaces, lifecycle, placement, storage, boot order, DNS, exposure, Vault, topology) and a fleet function that derives leases, DNS, port forwards, Vault roles, MicroVM hosting and boot ordering from it.
tags: [fleet, hosts, microvm, network, vault, design]
status: draft
---

# Host model: one record per machine

> Addresses in this document are fmf's example network (`192.168.50.0/24` for the LAN, `192.168.51-54.0/24`
> for the VLANs), not Campground's real ones; the structure, counts and findings are real.

**Status: phases 0 and 1 done for leases, DNS and port forwards; Vault roles, placement and boot order not
yet.** The `fmf.host` and `fmf.network.zones` options (`modules/nixos/system/host`), the fleet function
(`lib/fleet`, with tests) and the `fleet` command (`packages/scripts/fleet`) exist. Campground has a record for
all 44 hosts (`systems/<host>/host.nix`, loaded only once its fmf lock has the module), and its router leases,
DNS names and host port forwards are generated from them (`network/generated`). Results are in
[Phase 0 results](#phase-0-results), [Phase 1 import](#phase-1-import) and
[Phase 1: what now reads the records](#phase-1-what-now-reads-the-records); decisions are in
[Decisions](#decisions); phases and their gates are in [Phasing](#phasing-and-verification).

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

- **Duplicate addresses.** `edson` and `vm-pub-traefik` both had `192.168.50.20`. `authentik` and
  `vm-k8s-control-0` both have MAC `02:00:00:00:00:50`.
- **A stale lease.** `vm-pub-traefik` runs statically on `192.168.50.20` while its lease said `192.168.50.5`.
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
  ip   = "192.168.50.16";     # null = dynamic; no lease is generated and nothing is expected
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
  restartIfChanged = null;     # null (default) = not set; see below
};
```

`restartIfChanged` defaults to **not set** (`null`), so the model never turns it on for a VM that has it
off. That matters for the Vault VM: restarting it seals Vault and blocks everything that reads secrets,
which is why it is off today. A VM that should restart on deploy says `restartIfChanged = true`.

For each VM whose `runsOn` is a hypervisor, the fleet function produces for that hypervisor:

1. the `microvm.vms.<vm>` stanza (`flake`, `autostart`, `restartIfChanged`);
2. the per-VM directories (see Storage), including the Vault credential directory
   `/persist/system/var/lib/vault/<vm>` (mode 0700), which today is a hand-written `tmpfiles` line;
3. the standard shares (below) as `microvm.shares` in the guest;
4. ordering units (see Boot order);
5. the network attachment (see below).

**Standard shares**, derived from the record in this fixed order: `ro-store` (the host `/nix/store`),
`rw-store` (`/persist/vm-stores/<vm>/nix-store`, when `nixStore = "persistent"`), `vault-agent` (credentials),
`ssh-host-keys`, `root-password`; then the VM's own `storage` entries. Their paths are the same in 78 of the 81
standard shares in Campground's 20 placed MicroVMs, and they are the main source of copy-paste. What does vary,
measured on the real fleet (see [Phase 3 ground truth](#phase-3-ground-truth)), is a record option each:

| Variation seen | Option |
|---|---|
| Writable store: a share and overlay (9 VMs), an overlay with no share (5), none (6) | `nixStore = "persistent" \| "volatile" \| "none"` |
| No `root-password` share (7 VMs) | `standardShares.rootPassword = false` |
| `vault-agent` share without the agent enabled (1 VM) | `standardShares.vaultAgent = true` (default: follows `fmf.services.vault-agent.enable`) |
| Host directory owned by a service uid | `storage.<name>.owner` / `.group` |
| Host directories that already exist and must not be reset | `placement.hostDirectories = "external"` |

`/persist/system/secrets` (the `root-password` share's source) holds the host's own credentials and is shared
by every guest, so the model never generates it.

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
  tag        = null;      # virtiofs tag; default: the entry name
  mode       = "0755";    # host directory mode (ssh keys use 0700)
  readOnly   = false;
  order      = 100;       # position among this VM's shares (lower first, ties by name)
};
```

- The virtiofs tag defaults to the name; the host directory is created by `tmpfiles` with the given mode.
- **Order is fixed, not preserved.** The standard shares come first in the order above; the VM's own entries
  follow, sorted by `order`, then name. The hand-written lists in Campground used five different orders for the
  standard shares, and nothing depends on the order (guests find shares by tag), so the model does not try to
  reproduce them. The cost is real, though: shares are part of the VM's runner, so a VM whose list changes
  restarts on deploy when `restartIfChanged` is on. Switch one hypervisor at a time, and expect each VM to
  restart once.
- A shared host path (the PostgreSQL backups share, `/persist/postgresqlBackups/<app>`) is a storage entry
  with `hostPath` set, so it is still declared in one place.
- **Assertion:** two VMs must not claim the same `hostPath` unless both mark it shared.

### Boot order

Start-up order must be explicit because it is what fails after a power loss (the router, tang, then
Vault, then everything that needs Vault).

```nix
fmf.host.boot = {
  after = [ "vm-vault" ];        # MicroVMs on the SAME hypervisor that must start first
  hostUnits = [ ];               # units on the hypervisor this VM must start after (e.g. tang.socket)
};
```

- **Ordering is only between VMs on one hypervisor**, which is where it matters (blue-ridge: tang, then the
  Vault VM, then the VMs that read secrets). Each entry becomes `After=` and `Wants=` on
  `microvm@<vm>.service`. Today blue-ridge writes this by hand for four VMs.
- **Explicit, not inferred.** The model does not add ordering on its own (for example "every vault-agent VM
  after the Vault VM"); a VM lists what it needs.
- **Across machines it is an error.** systemd `After=` cannot order units on different machines, so a
  `boot.after` naming a VM on another hypervisor fails the build instead of silently doing nothing. There is
  no cross-machine wait.
- **Assertions:** a cycle, a dependency on itself, on a retired or unknown host, or on a physical host (use
  `hostUnits`) is an error.

### DNS

```nix
fmf.host.dns = {
  names = [ "mattermost.lan.aicampground.com" ];   # extra names for this host
  addAliases = true;                                # host name and lease name, short and FQDN
};
```

FQDNs use the zone's **`hostDomain`** (Campground: `lan-hosts.aicampground.com`, the domain AdGuard already
uses for host records). It is kept apart from the domain that *service* names live in, because the same
word is often both: the host `vault` is `192.168.50.3`, while the service name `vault.lan.aicampground.com`
points at the LAN Traefik. Using one domain for both would make them collide; the fleet function rejects any
name that would resolve to two addresses.

The **bare host name belongs to the primary interface.** A host with several leases named like itself (a second
VLAN, a stale extra NIC) gets the short name only for its primary address; its other interfaces get their
lease names and, in a different zone domain, an FQDN. Without this, `mattis` would resolve to three addresses.

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
| `leases.<zone>` | the router's `dhcp.staticLeases`, **merged** with the remaining hand-kept device leases (an overlap is an error) |
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
- An **active** MicroVM with no `runsOn` (a standby one may be unplaced), or one whose `runsOn` is not a
  physical host or is retired.
- A `boot.after` cycle, or one that crosses hypervisors.
- A reference to a retired host from anywhere.
- Two hosts claiming the same Vault role or alias.
- Two VMs claiming the same non-shared storage `hostPath`.
- A name that would resolve to two addresses.
- Warnings: a MicroVM MAC that is not locally administered (`02:...`); a static address inside the zone's
  DHCP pool (`dhcpRange`) that no lease reserves (lucas's situation); a DHCP interface with no MAC; a host
  with no interface.

The first run over the real fleet found three live contradictions; see [Phase 1 import](#phase-1-import).

## What replaces what

| Today | After |
|---|---|
| `blue-ridge/router/*-leases.nix` | **done**: host leases generated from the records; the files now hold only non-NixOS devices (later: `hints.devices`), merged in |
| `vm-adguard` `lanHosts`, `wifiHosts`, `iotHosts`, `k8sHosts` | **done**: generated (`network/generated/dns.nix`); only service names and wildcards stay in `vm-adguard` |
| `port-forwards.nix` destinations | **done**: forwards to hosts generated; only the Kubernetes load-balancer forwards stay hand-kept |
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
44 hosts. *Gate:* the generated host leases plus the remaining device leases equal today's lease set, and
the rewrites and role map equal what they replace (set comparisons, since order is not meaningful), checked
by a flake check over committed generated files. Device leases (iot, wifi, guest, appliances) are not
touched. *Risk:* a wrong lease can take
machines off the network. Deploy blue-ridge only after the comparison is exact, and keep the previous
generation.

**Phase 2: exposure and topology.**
Generated port forwards and circuit-breaker hints. *Gate:* forwards equal today's list; the Circuit
Breaker inventory is unchanged.

**Phase 3: placement, storage and boot order (the uniform parts).**
Derive `microvm.vms`, directories, standard and per-VM shares, the credential directory and same-host
ordering. *Gate:* for every VM, the evaluated `microvm.shares` (as a set of tag, source and mount point), the
host's VM-owned `tmpfiles` rules and the ordering equal the hand-written ones; share order is the one
deliberate difference (see [Storage](#storage)). **This is not cosmetic:** with `restartIfChanged`, a
changed share list changes the VM's runner and the VM restarts on deploy, and restarting `vm-vault`
seals Vault. Do the hypervisors one at a time, non-critical first (butler, ermy, lucas), and blue-ridge last.
*Done so far:* the options and pure derivation, with tests; the measured differences are in
[Phase 3 ground truth](#phase-3-ground-truth). *Not done:* the records' share data, the guest-side use of it,
the generated hypervisor file, and any switch-over.

**Phase 4: network attachment.**
The per-hypervisor zone-to-bridge map. This is the least uniform part and the easiest to get wrong
(bridge netfilter, `rp_filter`, trusted interfaces, VLAN bridges, macvtap). It may be left hand-written if
phase 3 delivers most of the value. Do it only with a recovery path to each hypervisor that does not rely
on the network being changed.

## Evaluation cost (decided by measurement, see Phase 0 results)

The router reading the whole fleet makes its build evaluate every host. For scale, the Vault-agent
extraction over all 44 hosts in one process took about 69 seconds and 3.7 GB; the host record is a small
slice and should be much cheaper, but **that has not been measured**. If it is too heavy for a build, the
fallback is committed generated files plus a drift check, as the Vault policies already work. Phase 0
decides this by measurement.

## Decisions

Settled in review on 2026-11-07:

1. **Namespace:** `fmf.host`, with the zone catalogue at `fmf.network.zones`. Campground-only consumers
   (router, AdGuard, port forwards) are wired downstream.
2. **Lifecycle:** `active`, `standby`, `retired`. Retired hosts stay in the repository as records.
3. **VM addresses are static.** An interface's `static` defaults to `true` for a MicroVM, so the guest
   configures its own address from the record and does not depend on a router deploy. A lease is still
   generated so the address stays reserved.
4. **Boot order:** only between VMs on the same hypervisor, explicit, no cross-machine wait.
5. **Zones** live in the network configuration (`fmf.network.zones`); interfaces refer to them by id.
6. **Topology and devices** share Circuit Breaker's hints: `topology` feeds `hints` (as defaults), and
   non-NixOS devices use `hints.devices`.
7. **Non-NixOS machines keep working.** The iot, wifi and guest devices and appliances have no host
   record and are not managed by it. Until devices are modelled, their leases stay where they are and
   the generated host leases are **added** to them, never replacing them; the router consumer must merge,
   and an address or MAC claimed by both is an error.
8. **`restartIfChanged`** is left unset unless a VM sets it, so the Vault VM keeps not restarting.
9. **Network attachment should become uniform** where possible (phase 4), with the per-hypervisor
   zone-to-bridge map; it stays hand-written until then.
10. **No Vault aliases for legacy roles.** A host that still logs in with an old role name gets credentials
    for its correctly named role instead (the role already exists, declared from its record), and the old
    role is then deleted. A role used by something outside the model (a device or a service account) stays
    declared by hand. The `vault.aliases` option and its handling in `lib/fleet` exist and are tested, but
    nothing uses them; remove them if that stays true.

## Phase 0 results

Measured on 2026-11-07 against Campground (44 hosts), with seven pilot records declared in a scratch
worktree only (blue-ridge, chesty, lucas, the retired edson, `vm-lan-traefik`, `vm-mattermost`,
`vm-pub-traefik`) and the real lease, share, tmpfiles, port-forward, DNS and Vault data as the reference.

- **Cost:** reading one host's record through the module system takes about 11 s and 0.56 GB; all 44, three
  at a time, took 209 s. Reading the whole fleet in **one** process did not finish on an 8 GB machine.
  So a consumer that evaluates every host at build time (the router reading all leases) is not viable on
  small machines; **consumers use committed generated files plus a drift check**, as the Vault policies do.
- **Fleet function:** 0 errors over all 44 hosts; 6 active, 1 retired, 37 unmanaged (no record yet, so
  ignored). One correct warning: the router's own interface has no MAC, so no lease.
- **Equality gates** (derived versus what exists today):

  | Gate | Result |
  |---|---|
  | Leases (pilot MACs) | all 6 existing leases reproduced exactly (MAC, address, name); one addition: a lease for `vm-mattermost`, which had none; nothing for retired edson |
  | `vm-mattermost` shares | identical, including order (7 shares) |
  | lucas `tmpfiles` for `vm-mattermost` | identical (6 directories) |
  | Port forwards to `vm-mattermost` | identical (2) |
  | DNS for the pilots | 10 records identical; 4 corrected (`pub-traefik` / `vm-pub-traefik` still pointed at the stale `192.168.50.5`); edson's records dropped; additions for hosts that had none |
  | Vault expected addresses | 5 roles identical (including the `lan-traefik` alias); 2 additions for hosts that had none; edson's role listed for removal |

- **Found while doing it:** using the service domain for host names collides (`vault` the host versus
  `vault.lan.aicampground.com` the service), hence the separate `hostDomain`; and storage order only matched
  by luck (alphabetical), hence the explicit `order`.

## Phase 1 import

Done on 2026-11-07. A one-shot generator built every record from what exists, not from anyone's memory:
each host's **evaluated** configuration (MicroVM interfaces and their MACs, the addresses a host sets
itself, which VMs each hypervisor runs with their autostart and restart flags), the router's five lease
files, its zone definitions and the port forwards. It reported every disagreement instead of resolving it
silently. The records were then evaluated through the real module on all 44 hosts.

**Layout in Campground.** One `systems/<host>/host.nix` per host (no edits to the hosts' `default.nix`),
and the zone catalogue in `network/zones.nix`. The flake loads both only when the locked fmf has the
module, so they are inert until the lock is bumped; with the old lock, sample hosts evaluate exactly as
before (same modules, same MicroVM shares, no record or zones loaded).

**Rules the import followed.**

- A VM's interface is matched to its lease by MAC; a physical host's by lease hostname (`<host>`,
  `<host>-<suffix>`), so extra NICs and second VLANs become extra interfaces.
- An address the host configures itself wins over its lease and sets `static = true`. It attaches to the
  lease that already has that address; failing that, to the lease named after the host (which is then
  reported as stale).
- Lease names that differ from what the fleet function would derive are kept explicitly (`leaseName`), so
  the generated leases are byte-for-byte the old ones.
- A VM no hypervisor runs is `standby` (it keeps its lease and role, and needs no `runsOn`).

**Problems it found, and what was done.**

| Found | Done |
|---|---|
| `vm-netobs`'s k8s tap used `vm-k8s-worker-butler`'s MAC: both running, both answering for `192.168.54.60` | netobs tap moved to `…:65`, which its own lease already said |
| `authentik` and `vm-k8s-control-0` shared a MAC | `vm-k8s-control-0` (not running) moved to `…:52` |
| `vm-topology` (standby) and `vm-agent` both claimed `192.168.50.26` | `vm-topology` moved to `192.168.50.28` |
| lucas is static on `192.168.50.89`, but its leases and DNS said `.189`/`.188`, and `.89` sat unreserved in the DHCP pool | lease reserves `.89`; stale second lease, DNS and docs fixed |
| mattis is `192.168.50.237` (its bridge carries the `mattis-wifi` MAC); DNS said `.235` | recorded as-is; the derived DNS corrects it |
| Seven VMs use static addresses with no lease | the derived leases add reservations |

**Gates** (records evaluated through the real module, compared with the current files):

| Gate | Result |
|---|---|
| Leases | all 43 host leases identical (zone, MAC, address, name); 25 device leases untouched; 7 reservations added; nothing lost |
| Placement | identical for all 20 placed VMs (hypervisor, autostart, restart flag; the Vault VM keeps not restarting) |
| Port forwards | all 6 forwards to hosts identical; 5 to Kubernetes LoadBalancer addresses stay hand-kept |
| DNS | 62 names identical; 6 corrected (mattis, pub-traefik); edson dropped (retired); device, service and wildcard names stay hand-kept |
| Vault expected addresses | 24 identical; the rest are corrections (lucas, the shared MACs) or additions (VLAN bridge addresses) |

The fleet function reports 0 errors and 5 warnings, all real: `glenn` has no known address, and four
hypervisors have a static k8s-bridge address inside the k8s DHCP pool that nothing reserves.

**Non-host data stays hand-kept, and must be merged in by the consumers:** the 25 device leases (iot,
wifi, cameras, AP, switch, pikvm, ATA-NUC), AdGuard's service and wildcard names, the Kubernetes
LoadBalancer port forwards, and legacy Vault role names until each is confirmed and declared as an alias.

## Phase 1: what now reads the records

Done on 2026-11-07, for the three network files. Generated by the `fleet` command into
`network/generated/` and committed (the router must not need the whole fleet evaluated to build):

| File | Replaces | Consumer |
|---|---|---|
| `leases.nix` | the host entries of the five lease files | `blue-ridge/default.nix` merges it, per zone, with the device leases |
| `dns.nix` | `lanHosts`, `wifiHosts`, `iotHosts`, `k8sHosts` and the FQDN helper in `vm-adguard` | `vm-adguard` takes it and adds only service names and wildcards |
| `forwards.nix` | the forwards to hosts in `port-forwards.nix` | `blue-ridge/default.nix` merges it with the hand-kept Kubernetes forwards |

The five `*-leases.nix` files now hold **only the 25 machines that are not hosts** (cameras, printer, iot
devices, access point, switch, pikvm, ATA-NUC), with a note not to add a host there. Device leases still take
part in DNS and in the clash checks.

**Checked against the real configuration, old versus new** (blue-ridge and `vm-adguard` evaluated from a
clean checkout of the old state and from the new tree):

| Check | Result |
|---|---|
| Leases blue-ridge would apply | 68 before, 75 after: none lost, 7 added (the VMs that used static addresses with no lease) |
| Port forwards blue-ridge would apply | identical (11) |
| AdGuard rewrites | 125 before, 219 after: 115 identical; 6 corrected (`mattis`, `pub-traefik`); `edson` dropped; 98 added for hosts and devices that had no name |
| `circuit-breaker`, library and drift-check tests | pass; the drift check fails on a hand-edited lease, a removed DNS name, a removed forward, a missing file, and a device that clashes with a host |

**Two names disappear on purpose:** `chesty-wifi.wifi-hosts…` and `mattis-wifi.wifi-hosts…` were filed under
the wifi domain although those addresses are in the LAN zone; they now resolve as `….lan-hosts…`. Nothing
referenced the old ones.

**`vault-access` reads the generated leases too.** It derives each role's expected addresses from the lease
files by MAC, and those files no longer hold the hosts, so it merges `network/generated/leases.nix` in
(`--generated-leases`). Regenerating gave the 7 new VMs expected addresses and changed nothing else.

**Found while wiring it, and removed.** A forward of UDP 51820 was described as "Netbird WireGuard to
webb", but its destination was butler's address, not webb's. Butler has no netbird client, nothing in the
configuration listens on 51820, and the remote-access WireGuard that is actually used (a VPN server on a
VM that runs on the router, forwarded on its own port) was a different forward. Importing it onto butler's
record made the mismatch visible; with the owner's confirmation it was deleted.

**Not wired yet:** Vault roles (see decision 10),
hypervisor hosting and boot order (phase 3), network attachment (phase 4), and building the router's zone
definitions from `fmf.network.zones` (today the zone catalogue and the router's zones are two copies).

## Risks, stated plainly

- **Network lock-out.** Leases and bridges are how machines reach each other. Phases 1 and 4 can take
  machines offline; the gates and one-at-a-time deploys are the mitigation, not a guarantee.
- **VM restarts on deploy.** Any change to a VM's runner restarts it. For Vault this means sealing and an
  outage for everything that reads secrets.
- **One more place to be wrong.** A mistaken record now propagates to the router, DNS and Vault together.
  The assertions and the equality gates exist to stop that before deployment.
- **Evaluation weight.** Unmeasured; see above.

## Phase 3 ground truth

Measured on 2026-11-08 by evaluating Campground's real configuration for the 20 MicroVMs that have a host
placement and the 7 hypervisors that run them (each host evaluated on its own; the whole fleet in one
evaluation does not fit in 8 GB). This is what the derivation had to be reconciled with; the spec above was
written first and was wrong in these places.

**Shares (131 in total, all virtiofs, none read-only).**

- 78 of the 81 standard shares follow one path pattern exactly. Three do not: `vm-k8s-control-2` and
  `vm-netobs` share their credentials from `/var/lib/vault/<vm>` rather than `/persist/system/var/lib/vault/<vm>`,
  and `vm-websites` mounts them at `/var/lib/vault` rather than `/var/lib/vault/vm-websites`. These are
  hand-written exceptions to normalise one VM at a time (copy the credentials, change, deploy, restart,
  confirm the agent renders, delete the old copy), not something the derivation reproduces.
- The standard shares appear in five different orders, and VM-specific shares sit between them (`vm-vault`
  has `vault-log` before `ssh-host-keys`). Order has no effect on the guest, so the model fixes one order.
- The writable store is `persistent` in 9 VMs, `volatile` (overlay set, no share) in 5, and `none` in 6.
- 13 VMs have a `root-password` share and 7 do not. One VM has a `vault-agent` share without the agent.

**Hypervisor directories.**

- Most are not declared at all: 38 share sources have no `tmpfiles` rule. On blue-ridge only `vm-netobs` has
  any; `vm-vault`, `vm-adguard`, `vm-gitea`, `vm-lan-traefik` and `vm-websites` run on directories created by
  hand. A `d` rule resets the mode and owner of an existing directory, so these VMs start as
  `placement.hostDirectories = "external"` until their real modes have been checked on the host.
- Where declared, modes are `0755 root` (78 data directories), `0700 root` (23) and `0700` for a service uid
  (`10000` twice, `286` once). The credential directory is `0700` everywhere except one host's `0755`.

**Flags and ordering.**

- `restartIfChanged` is true for every VM except `vm-vault`; `autostart` is true except for `vm-photos`.
- Ordering is per VM, not "everything after the Vault VM": `vm-gitea`, `vm-lan-traefik` and `vm-websites`
  start after `vm-vault`, `vm-adguard` and `vm-netobs` do not. `vm-vault` also waits on `tang.socket` and the
  tang mount. The `nftables` and `microvm-ssh-isolation` requirements come from other modules and are not part
  of the model.

**Gate, as it will actually be run.** Per hypervisor, evaluate it before and after switching to the derived
output and compare: the `microvm.vms` flags, the VM-owned `tmpfiles` rules as a set, and the `microvm@*`
`after`/`wants`. Per VM, compare the share list as a set of (tag, source, mount point); the order is
deliberately the one thing that changes.

## Evidence this was written from

Counts and file contents were read directly from the repositories on 2026-11-07: the lease files, the
`microvm.vms` stanzas and `tmpfiles` lines on blue-ridge, lucas and chesty, `vm-mealie`'s shares, the
blue-ridge ordering block, the AdGuard `lanHosts` map, the router zone definitions, and fmf's Circuit
Breaker hints. Per-hypervisor VM counts (blue-ridge about 6, chesty and lucas about 4, sledge and webb 2,
butler and ermy 1) come from a pattern match and are approximate. Nothing here has been run.
