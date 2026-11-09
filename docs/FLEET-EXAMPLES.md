---
type: Examples
title: Fleet examples - copy-paste records for VMs and networking
description: Ready-to-copy host, storage and attachment records for common cases - networking only, MicroVMs only, both together, two interfaces, VLANs, Vault, standby and retired hosts, macvtap, existing data folders and port forwards.
tags: [fleet, hosts, examples, microvm, network]
status: draft
---

# Fleet examples

Copy the one that matches what you want and change the names and addresses. Every example uses the same example
network, defined once in `network/zones.nix` (see [Getting started](FLEET-GETTING-STARTED.md#step-2-describe-your-networks-once)):

| Zone | Subnet | Gateway | Used here for |
|---|---|---|---|
| `lan` | `192.168.50.0/24` | `192.168.50.1` | Most machines |
| `dmz` | `192.168.60.0/24` | `192.168.60.1` | Machines that face the internet (VLAN 60) |

Each example says which file it belongs to. Files are in `systems/x86_64-linux/<name>/`. After any change: `git add`,
run `fleet`, review `network/generated/`, commit. Which examples were actually run is listed at the end.

- [A. Networking only](#a-networking-only): [A1 a laptop on DHCP](#a1-a-laptop-on-dhcp) ·
  [A2 a server with a fixed address](#a2-a-server-with-a-fixed-address) ·
  [A3 a machine with two cards](#a3-a-machine-with-two-cards) · [A4 a printer with no record](#a4-a-printer-with-no-record) ·
  [A5 forward a port](#a5-forward-a-port)
- [B. MicroVMs only](#b-microvms-only): [B1 the smallest VM setup](#b1-the-smallest-vm-setup) ·
  [B2 a VM with an existing data folder](#b2-a-vm-with-an-existing-data-folder) ·
  [B3 a VM that starts after another](#b3-a-vm-that-starts-after-another) ·
  [B4 a VM that uses Vault](#b4-a-vm-that-uses-vault) · [B5 a VM that uses DHCP](#b5-a-vm-that-uses-dhcp)
- [C. Both together](#c-both-together): [C1 a small homelab](#c1-a-small-homelab) ·
  [C2 a VM on two networks](#c2-a-vm-on-two-networks) · [C3 a hypervisor with macvtap](#c3-a-hypervisor-with-macvtap) ·
  [C4 a VM whose tap name differs](#c4-a-vm-whose-tap-name-differs)
- [D. Life cycle](#d-life-cycle): [D1 standby](#d1-a-standby-vm) · [D2 retired](#d2-a-retired-host)

## A. Networking only

### A1. A laptop on DHCP

The laptop asks DHCP; a lease makes DHCP always give it this address, and it gets a DNS name.

```nix
# systems/x86_64-linux/laptop/host.nix
{...}: {
  fmf.host = {
    kind = "physical";
    network.interfaces.wifi = {
      ip = "192.168.50.70";
      mac = "aa:bb:cc:00:00:70";
      zone = "lan";
    };
  };
}
```

Result: `leases.nix` gets `{mac = "aa:bb:cc:00:00:70"; ip = "192.168.50.70"; hostname = "laptop";}`, and `dns.nix` gets
`laptop` and `laptop.lan-hosts.example.com`. Use `ip = null;` instead to say "DHCP decides, reserve nothing".

### A2. A server with a fixed address

The server sets its own address. The record still reserves it so nothing else is given it.

```nix
{...}: {
  fmf.host = {
    kind = "physical";
    network.interfaces.lan = {
      ip = "192.168.50.30";
      mac = "aa:bb:cc:00:00:30";
      static = true;
      zone = "lan";
    };
  };
}
```

`fleet` warns if a static address sits inside the zone's DHCP pool and no lease reserves it. Giving the interface its
`mac` clears the warning.

### A3. A machine with two cards

```nix
{...}: {
  fmf.host = {
    kind = "physical";
    network.interfaces = {
      eth = {
        ip = "192.168.50.30";
        mac = "aa:bb:cc:00:00:30";
        primary = true; # required when there is more than one interface
        zone = "lan";
      };
      wifi = {
        ip = "192.168.50.31";
        mac = "aa:bb:cc:00:00:31";
        zone = "lan";
      };
    };
    dns.names = ["files"]; # an extra name for the primary address
  };
}
```

Names: `nas` and `files` resolve to `.30`, and `nas-wifi` to `.31` (plus the `.lan-hosts.example.com` forms of the first
two kinds). Leases: hostnames `nas` and `nas-wifi`. To name a lease yourself, set `leaseName = "..."` on the
interface.

### A4. A printer with no record

Things that are not NixOS machines have no record. List them in `network/devices/lan-leases.nix` (the name says the
zone):

```nix
[
  {
    mac = "3c:2a:f4:11:22:33";
    ip = "192.168.50.60";
    hostname = "printer";
  }
]
```

and run `fleet --device-leases 'network/devices/*-leases.nix'`. The printer gets DNS names and is checked against the
hosts, but it is **not** written into `leases.nix`; your DHCP server reads this file as well (see
[the networking tutorial](FLEET-TUTORIAL-NETWORK.md#a-a-plain-nixos-machine-running-dnsmasq-and-nat)).

### A5. Forward a port

On the machine that receives the traffic:

```nix
fmf.host.expose = [
  {port = 443; description = "HTTPS to the web server";}
  {port = 51820; destPort = 51820; proto = "udp"; description = "WireGuard";}
  {port = 2222; destPort = 22; description = "SSH to this machine on a different outside port";}
];
```

`port` is what the router listens on, `destPort` (default: the same) is the machine's port, `proto` defaults to `tcp`.
Result in `forwards.nix`: `{port = 2222; destination = "192.168.50.30"; protocol = "tcp"; description = ...; destinationPort = 22;}`.

## B. MicroVMs only

### B1. The smallest VM setup

One hypervisor, one VM. Everything else you need is in [the VM tutorial](FLEET-TUTORIAL-VMS.md). The records:

```nix
# systems/x86_64-linux/hv1/host.nix
{...}: {
  fmf.host = {
    kind = "physical";
    network.interfaces.lan = {
      ip = "192.168.50.10";
      mac = "aa:bb:cc:00:00:10";
      static = true;
      zone = "lan";
    };
  };
}
```

```nix
# systems/x86_64-linux/hv1/attachment.nix
{...}: {
  fmf.host.hypervisor.networks.lan.bridge = "br0"; # a bridge you already have
  fmf.host.hypervisor.tapRules = true;
}
```

```nix
# systems/x86_64-linux/vm-db/host.nix
{...}: {
  fmf.host = {
    kind = "microvm";
    placement.runsOn = "hv1";
    network = {
      derive = true;
      interfaces.lan = {
        ip = "192.168.50.21";
        mac = "02:00:00:00:00:21";
        zone = "lan";
      };
    };
  };
}
```

```nix
# systems/x86_64-linux/vm-db/storage.nix
{...}: {
  fmf.host = {
    derive = true;
    standardShares.rootPassword = false;
    storage.postgres.mountPoint = "/var/lib/postgresql";
  };
}
```

### B2. A VM with an existing data folder

The data already lives at `/srv/www` on the hypervisor and must not be moved or have its owner reset.

```nix
# systems/x86_64-linux/vm-web/storage.nix
{...}: {
  fmf.host = {
    derive = true;
    nixStore = "none"; # the VM's Nix store is read-only: no writable overlay
    standardShares.rootPassword = false;
    storage.www = {
      mountPoint = "/var/www";        # where the VM sees it
      hostPath = "/srv/www";          # where it already is on the hypervisor
      createDirectory = false;        # do not generate a rule that resets its owner and mode
    };
  };
}
```

`nixStore = "none"` is for a VM that does not need to install packages by itself; then you should not need the two
`nix.optimise` lines in its `default.nix` (the check that needs them is about the writable store, which this VM does not have; not built here). With `"persistent"` or `"volatile"` you do, because those give the VM a
writable store.

### B3. A VM that starts after another

```nix
fmf.host.boot.after = ["vm-db"];          # a VM on the SAME hypervisor
fmf.host.boot.hostUnits = ["tang.socket"]; # and/or units on the hypervisor itself
```

`fleet` writes `microvm@vm-web` with `after` and `wants` on `microvm@vm-db.service`. A VM that is not a VM, or runs on
another machine, is an error.

### B4. A VM that uses Vault

```nix
# default.nix
fmf.services.vault-agent = {
  enable = true;
  settings.vault = {
    address = "https://vault.lan.example.com";
    role-id = "/var/lib/vault/vm-app/role-id";
    secret-id = "/var/lib/vault/vm-app/secret-id";
  };
};
```

```nix
# host.nix
fmf.host.boot.after = ["vm-vault"]; # if the Vault VM is on the same hypervisor
```

Nothing goes in `storage.nix`. Because vault-agent is enabled, the record adds the credentials share:
`/persist/system/var/lib/vault/vm-app` on the hypervisor appears at `/var/lib/vault/vm-app` in the VM. The hypervisor
creates the directory with mode 0700; **you** copy `role-id` and `secret-id` into it ([Vault runbook](VAULT-RUNBOOK.md)).

For the Vault server's own VM, **leave `placement.restartIfChanged` unset** so a deploy never seals it, and wait for
the unlock helper: `fmf.host.boot.hostUnits = ["tang.socket"];`.

### B5. A VM that uses DHCP

Without `network.derive`, the VM keeps its own network configuration in `default.nix`. Say so in the record so the
lease is still generated and the hypervisor still knows its tap:

```nix
# host.nix
{...}: {
  fmf.host = {
    kind = "microvm";
    placement.runsOn = "hv1";
    network.interfaces.lan = {
      ip = "192.168.50.22";
      mac = "02:00:00:00:00:22";
      static = false; # the VM asks DHCP; the lease makes DHCP answer with .22
      zone = "lan";
    };
  };
}
```

```nix
# default.nix (what you keep writing by hand)
microvm.interfaces = [{type = "tap"; id = "vm-app"; mac = "02:00:00:00:00:22";}];
networking.useDHCP = true;
```

`id` is the tap's name on the hypervisor (15 characters at most). It must be what the record implies (the host name),
or be set in the record: see [C4](#c4-a-vm-whose-tap-name-differs). The generated lease holds this address in DHCP
as long as the router reads `leases.nix`.

## C. Both together

### C1. A small homelab

Layout and what each file is:

```
flake.nix                               wiring (see Getting started)
network/
  zones.nix                             your networks
  microvm-host.nix                      reads generated/microvms.nix (paste once)
  devices/lan-leases.nix                printers, cameras: machines with no record
  generated/                            written by fleet. Never edit.
systems/x86_64-linux/
  gateway/{default,host}.nix            router + DHCP + DNS: READS leases, dns, forwards
  hv1/{default,host,attachment}.nix     hypervisor: READS microvms
  nas/{default,host}.nix                a plain host: only a record
  vm-db/{default,host,storage}.nix      a VM
  vm-web/{default,host,storage}.nix     a VM with expose = [443]
checks/fleet/default.nix                optional: fail the build if fleet was not run
```

Only two machines **read** the generated files: the gateway (leases, DNS, forwards) and the hypervisor (microvms). Every
other machine just has a record. A new machine is: write its record, run `fleet`, commit, deploy the reader(s).

### C2. A VM on two networks

A web server with an inside address and a second address in the `dmz`:

```nix
# systems/x86_64-linux/vm-web/host.nix
{...}: {
  fmf.host = {
    kind = "microvm";
    placement.runsOn = "hv1";
    network = {
      derive = true;
      interfaces = {
        lan = {
          ip = "192.168.50.20";
          mac = "02:00:00:00:00:20";
          primary = true;       # required: more than one interface
          zone = "lan";
        };
        dmz = {
          ip = "192.168.60.20";
          mac = "02:00:00:00:00:a0";
          zone = "dmz";
          guestName = "public0"; # the name inside the VM; default is "<interface>0" = dmz0
        };
      };
    };
  };
}
```

The hypervisor needs a bridge for **each** zone, and the zone must exist in `zones.nix`:

```nix
# systems/x86_64-linux/hv1/attachment.nix
{...}: {
  fmf.host.hypervisor.networks = {
    lan.bridge = "br0";
    dmz.bridge = "br1";
  };
  fmf.host.hypervisor.tapRules = true;
}
```

What you get: taps named `vm-web` (primary) and `vm-web-dmz`, joined to `br0` and `br1`; inside the VM, links `lan0`
and `public0`; the zone's **gateway only on the primary** interface; DNS and lease names `web` and `web-dmz`. A zone a
hypervisor has no bridge for is an error (`hv1 has no attachment for zone dmz`). A tap can only join a bridge, never a
VLAN interface such as `br0.60`.

### C3. A hypervisor with macvtap

A hypervisor with no bridge can hand VMs the network card directly with a macvtap. The hypervisor says so:

```nix
# systems/x86_64-linux/chesty/attachment.nix
{...}: {
  fmf.host.hypervisor.networks.lan.macvtap = {
    link = "enp7s0"; # the real network card
    mode = "bridge";
  };
}
```

and the VM's record marks the interface:

```nix
fmf.host.network.interfaces.lan = {
  attach = "macvtap";
  ip = "192.168.50.25";
  mac = "02:00:00:00:00:25";
  zone = "lan";
};
```

`network.derive` does not write a macvtap interface (the network card is the hypervisor's to name), so the VM keeps its
`microvm.interfaces` in `default.nix`:

```nix
microvm.interfaces = [{
  type = "macvtap";
  id = "vm-app";
  mac = "02:00:00:00:00:25";
  macvtap = {link = "enp7s0"; mode = "bridge";};
}];
```

No tap rule is generated for macvtap. With macvtap, the hypervisor itself cannot talk to its own VMs over that card.

### C4. A VM whose tap name differs

The tap's name on the hypervisor defaults to the host name (`vm-web-app` is 10 characters, fine). Linux allows 15
characters at most. When the VM's `microvm.interfaces` uses another name, or the host name is too long, say it in the
record. It is in a separate file so the VM's record stays clean:

```nix
# systems/x86_64-linux/vm-media-library/attachment.nix
{...}: {
  fmf.host.network.interfaces.lan.id = "vm-media-lib";
}
```

If the record says `vm-media-lib` and the VM's `microvm.interfaces` says something else, `fleet` warns that the VM's
interface is named differently on the hypervisor from the record.

## D. Life cycle

### D1. A standby VM

Keeps its name, lease and address; is not started and receives no forwards.

```nix
# host.nix
{...}: {
  fmf.host = {
    kind = "microvm";
    lifecycle = "standby";
    network.interfaces.lan = {
      ip = "192.168.50.90";
      mac = "02:00:00:00:00:90";
      zone = "lan";
    };
    # no placement.runsOn needed while it is standby
  };
}
```

Give it a `storage.nix` with `derive = true` now, so its shares are derived from the start. Nothing is generated for a
hypervisor until you add `placement.runsOn` and remove `lifecycle`.

### D2. A retired host

```nix
{...}: {
  fmf.host = {
    kind = "physical";
    lifecycle = "retired";
    retired = {
      since = "2026-11-09";
      reason = "permanently offline";
    };
  };
}
```

Nothing is generated for it, and any record that still refers to it is an error. Its `default.nix` must still
evaluate.

## What was run

In a scratch downstream flake against this repository's `fmf`, `fleet` was run for: A1-A4's shape (a host with two
interfaces, `dns.names`, a device lease file, a device clashing with a host), A5's forward, B1, B2 (with
`nixStore = "none"` and a custom `hostPath`), B3, C1's layout, C2 (including the guest links, taps and bridges it
derives) and the error cases quoted in [troubleshooting](FLEET-TROUBLESHOOTING.md). **Not run:** A1, A2, B4, B5, C3,
C4, D1 and D2 as written (they are the same fields as the runs above in other combinations; D2's behaviour is
described in the host model), and nothing was deployed or booted. The `network.derive` guest settings were checked by
evaluation only.
