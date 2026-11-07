---
type: Reference
title: Circuit Breaker inventory format (schema v1)
description: The versioned, Circuit-Breaker-independent document the flake exporter produces and the reconciler consumes.
tags: [circuit-breaker, reference, schema]
generated: { by: claude-agent/sonnet-5-5, at: 2026-11-01T12:00:00Z }
---

# Circuit Breaker inventory format (schema v1)

Produced by `lib.fmf.circuitBreaker.mkInventory` (`lib/circuit-breaker/inventory.nix`),
validated by `circuit-breaker-sync --validate` (`cb_sync/inventory.py`). It deliberately
knows nothing about Circuit Breaker's API: a different consumer, or a different CB release,
needs only a new adapter. Context: [architecture](CIRCUIT-BREAKER.md).

Properties: **deterministic** (sorted, stable ids, byte-identical output for identical
input), **versioned**, **secret-free** (only an allow-list of option paths is read; the
validator also rejects credential-looking keys and values), and **declarative** (it never
states a runtime condition).

## Document

```json
{
  "schemaVersion": 1,
  "kind": "circuit-breaker-inventory",
  "semantics": "declared",
  "generator": { "name": "fmf-circuit-breaker-exporter", "version": "1" },
  "source": { "name": "campground", "revision": "<git sha>", "systems": ["blue-ridge", "…"] },
  "resources": [ … ],
  "relationships": [ … ],
  "monitors": [ … ],
  "diagnostics": [ … ]
}
```

`source` and `diagnostics` do not affect the change digest: a commit that does not change the
topology is not a change.

## Resource

```json
{
  "id": "vm/vm-websites",
  "type": "vm",
  "name": "vm-websites",
  "parent": "host/blue-ridge",
  "tags": ["role:kubernetes"],
  "state": "declared",
  "origin": { "kind": "nixosConfiguration", "ref": "vm-websites", "path": "…" },
  "attributes": { "primaryAddress": "192.168.50.11", "addressSource": "dhcp-reservation", "vcpu": 2, "memoryMb": 2047, "…": "…" }
}
```

| Field | Notes |
| --- | --- |
| `id` | Stable identity: `host/<attr>`, `vm/<attr>`, `device/<name>`, `net/<zone-or-cidr>`, `svc/<system>/<service>`, `container/<system>/<name>`. Never contains an IP address except for networks derived from one. |
| `type` | `host`, `vm`, `container`, `network`, `service`, `device` |
| `parent` | Owning resource id: VM → physical host, service → host/VM, container → host/VM. Must exist. |
| `origin.kind` | `nixosConfiguration`, `hint`, `derived` |
| `state` | always `declared` |
| `attributes` | Typed per resource type, absent when unknown (never `null` placeholders) |

Notable attributes: hosts and VMs – `hostName`, `platform`, `architecture`, `osRelease`,
`configurationRevision`, `primaryAddress` + `addressSource` (`static`, `dhcp-reservation`,
`hint`), `defaultGateway`, `nameservers`, `interfaces[]`, `guestInterfaces[]`
(`tapId`, `mac`, `attachedTo`), `firewall`, `storage[]`, `vcpu`, `memoryMb`, `placement`
(`placed`/`unplaced`), `autostart`. Services – `kind`, `source`, `address`, `ports[]`
(`port`, `protocol`, `exposure`: `open`, `interface`, `closed`, `firewall-disabled`),
`publishedHostnames`, `url`. Networks – `cidr`, `vlanId`, `gateway`, `description`,
`isolation`.

## Relationship

| `type` | From → to | Meaning |
| --- | --- | --- |
| `member_of` | host/vm/container → network | Has an address in that network (layer 3). Not a cable. |
| `attached_to` | vm → host | The VM's TAP is enslaved to this bridge on the host (`attributes.bridge`, `tap`). |
| `proxies_to` | reverse-proxy service → backend service | From the proxy's declared routers (`attributes.router`, `hostnames`). |
| `uses` | host/vm → service | `purpose`: `secrets` (vault agent) or `dns` (nameserver). |
| `mounts_from` | host → host/service | NFS/CIFS/Gluster mounts. |
| `connects_to` | any → any | Only from explicit hints. |

Ids are `rel/<type>/<from>/<to>[/<qualifier>]`. Both ends must exist.

## Monitor

```json
{ "id": "mon/svc/vm-vault/vault/http", "target": "svc/vm-vault/vault", "checkType": "http",
  "host": "vault.lan.example", "config": { "url": "https://vault.lan.example/", "verify_tls": true },
  "intervalSecs": 60, "name": "vault https" }
```

`checkType`: `icmp`, `tcp`, `http`, `dns`. `config` is passed to CB's check
configuration. `intervalSecs` 10–86400. Targets must exist; monitors of unplaced VMs are not
generated.

## Diagnostics

`{ level: info|warning|error, code, subject, message }` – see the architecture document for
the codes.

## Compatibility rules

- The reconciler accepts only the `schemaVersion`s it lists (exit 6 otherwise).
- Adding optional attributes does not bump the version; changing the meaning of an id, a
  relationship type or a required field does.
- Ids are an API: renaming one makes the reconciler see a removal plus an addition.
