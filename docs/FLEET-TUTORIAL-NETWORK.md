---
type: Tutorial
title: Leases, DNS and port forwards from records
description: Describe machines once in host records and let fleet generate the DHCP reservations, DNS names and router port forwards, then wire those files into a plain NixOS gateway, fmf's router module, or AdGuard - written for someone who has not used the host model before.
tags: [fleet, hosts, tutorial, network, dhcp, dns, port-forwards]
status: draft
---

# Leases, DNS and port forwards from records

By the end of this tutorial, adding a machine to your network means writing one small file. The router's DHCP
reservations, the DNS server's names and the router's port forwards all follow from it, and `fleet` stops you from
giving two machines the same address.

Do [Getting started](FLEET-GETTING-STARTED.md) first (the flake wiring, `zones.nix` and the empty generated files).
This page does not need any MicroVMs. If you also run VMs, [MicroVMs from records](FLEET-TUTORIAL-VMS.md) uses the
same records for them, and the files below pick them up automatically.

## What you get

`fleet` writes three files for the network, and you point your router and DNS server at them:

| File | What is in it | Who reads it |
|---|---|---|
| `network/generated/leases.nix` | One reservation per interface that has a MAC and an IP: `{mac; ip; hostname;}`, grouped by zone | The DHCP server |
| `network/generated/dns.nix` | Name to address: every host by name, short and as `<name>.<hostDomain>` | The DNS server |
| `network/generated/forwards.nix` | Ports the router forwards to a host | The router's NAT |

The fourth file, `microvms.nix`, is for hypervisors; ignore it here.

## Step 1: describe the machines

One `host.nix` per machine, next to its `default.nix`. These are the files from Getting started plus a second
machine.

```nix
# systems/x86_64-linux/nas/host.nix
{...}: {
  fmf.host = {
    kind = "physical";
    network.interfaces.lan = {
      ip = "192.168.50.30";
      mac = "aa:bb:cc:00:00:30";
      zone = "lan";
    };
  };
}
```

```nix
# systems/x86_64-linux/gateway/host.nix  (the router / DHCP server itself)
{...}: {
  fmf.host = {
    kind = "physical";
    network.interfaces.lan = {
      ip = "192.168.50.1";
      static = true; # it sets this address itself and has no lease to ask for
      zone = "lan";
    };
  };
}
```

`gateway` has no `mac`, so no lease is made for it; it is still in DNS. That is correct: the DHCP server does not
lease an address to itself.

### A machine with more than one interface

Give each network card its own block. When there is more than one you must say which is the **primary** one:

```nix
fmf.host = {
  kind = "physical";
  network.interfaces = {
    eth = {
      ip = "192.168.50.30";
      mac = "aa:bb:cc:00:00:30";
      primary = true; # the address a plain "nas" resolves to
      zone = "lan";
    };
    wifi = {
      ip = "192.168.50.31";
      mac = "aa:bb:cc:00:00:31";
      zone = "lan";
    };
  };
  dns.names = ["files"]; # extra names for the primary address
};
```

Without `primary = true`, `fleet` stops with `nas: has 2 interfaces and none is marked primary`. The result:

| Name | Address | Why |
|---|---|---|
| `nas`, `nas.lan-hosts.example.com` | `192.168.50.30` | the primary interface |
| `nas-wifi`, `nas-wifi.lan-hosts.example.com` | `192.168.50.31` | other interfaces are named `<host>-<interface>` |
| `files` | `192.168.50.30` | extra name from `dns.names` (this exact name only) |

An interface in another zone (for example a VLAN) works the same way; set its `zone`.

## Step 2: machines that are not NixOS

A printer, a camera or an access point has no `host.nix`. List those in a plain file of your own. The **file name
says the zone**: `lan-leases.nix` is for the `lan` zone.

```nix
# network/devices/lan-leases.nix
[
  {
    mac = "3c:2a:f4:11:22:33";
    ip = "192.168.50.60";
    hostname = "printer";
  }
]
```

Tell `fleet` where they are. Its default looks in a Campground-style router directory, so give yours:

```bash
nix run --inputs-from . fmf#fleet -- --device-leases 'network/devices/*-leases.nix'
```

Devices are **not** copied into `leases.nix` (they are yours to keep); they **are** added to `dns.nix` and
included in the clash check. If a printer is given an address a host already has, `fleet` stops with
`nas: address 192.168.50.30 is used by nas, device printer`. Your DHCP server therefore reads **both**: the
generated leases and this file (shown below).

## Step 3: run `fleet`

```bash
git add systems network
nix run --inputs-from . fmf#fleet -- --device-leases 'network/devices/*-leases.nix'
```

```
wrote network/generated/: 1 host leases, 6 DNS names, 0 port forwards, 0 generated MicroVMs (2 active hosts, 0 standby, 0 retired)
```

Your two hosts and the printer are now in the files. Run `--show` to see one machine's slice:

```bash
nix run --inputs-from . fmf#fleet -- --show nas
```

## Step 4: let the gateway read the files

Nothing changes on a machine until something reads the generated files. Three ways, from simplest to most
complete. Pick the one that matches your router.

### A. A plain NixOS machine running dnsmasq and NAT

This is the smallest working consumer. It does not use any fmf router module. Put it in the gateway's
`default.nix`:

```nix
{lib, ...}: let
  # Hosts (generated) plus the machines that are not NixOS hosts (hand-kept).
  leases =
    ((import ../../../network/generated/leases.nix).lan or [])
    ++ import ../../../network/devices/lan-leases.nix;
  names = import ../../../network/generated/dns.nix;
  forwards = import ../../../network/generated/forwards.nix;
in {
  # ... the rest of the gateway's configuration ...

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "eno1";
      dhcp-range = ["192.168.50.100,192.168.50.200,12h"];
      # DHCP: every host gets the address in its record.
      dhcp-host = map (l: "${l.mac},${l.ip},${l.hostname}") leases;
      # DNS: every host name resolves to the address in its record.
      address = lib.mapAttrsToList (name: ip: "/${name}/${ip}") names;
    };
  };

  # Port forwards: every `expose` in a record.
  networking.nat = {
    enable = true;
    externalInterface = "eno2";
    internalInterfaces = ["eno1"];
    forwardPorts = map (f: {
      sourcePort = f.port;
      destination = "${f.destination}:${toString (f.destinationPort or f.port)}";
      proto = f.protocol;
    }) forwards;
  };
}
```

Replace `eno1` (inside) and `eno2` (outside) with your interfaces. `../../../` is the path from
`systems/x86_64-linux/gateway/` back to the flake root. Read `leases` as "the list of `{mac; ip; hostname;}`", and
the three `map`s as "turn each entry into one line of dnsmasq or NAT configuration".

### B. fmf's router module (`fmf.router`)

If your router uses fmf's router module, the pattern is the one `blue-ridge` uses in this repository
(`systems/x86_64-linux/blue-ridge/default.nix`). Read the files in a `let`, and use them where you used to type the
tables:

```nix
{lib, ...}: let
  generated = {
    leases = import ../../../network/generated/leases.nix;
    forwards = import ../../../network/generated/forwards.nix;
  };
in {
  fmf.router = {
    zones.zones.lan.dhcp.staticLeases = generated.leases.lan or [];
    # one line per zone you have, for example:
    # zones.zones.wifi.dhcp.staticLeases = generated.leases.wifi or [];
    portForwards = generated.forwards;
  };
}
```

If you have some leases that are not hosts (devices), put them in a list of your own and add them:
`staticLeases = (generated.leases.lan or []) ++ import ./devices/lan-leases.nix;`.

### C. A DNS server with a rewrite table (AdGuard Home)

`dns.nix` is a plain set of `name = address`, which is the shape of a "DNS rewrite" table. Campground's AdGuard VM
does exactly this and adds only what is not a host (service names and wildcards):

```nix
let
  generatedHostNames = import ../../../network/generated/dns.nix;
  allRewrites =
    generatedHostNames
    // {
      # not hosts: service names that point at a proxy
      "*.lan.example.com" = "192.168.50.20";
    };
in {
  fmf.services.adguard.dns.rewrites = allRewrites;
}
```

Use the same idea for any server that takes a name-to-address list.

## Step 5: expose a port

Port forwards belong on the machine that receives them. In the web server's record:

```nix
fmf.host.expose = [
  {
    port = 443;                       # the port on the router
    description = "HTTPS to the web server";
  }
  {
    port = 8443;
    destPort = 443;                   # the port on the machine, if different
    proto = "udp";                    # default "tcp"
    description = "Something on UDP";
  }
];
```

Run `fleet` and the entry appears in `forwards.nix`:

```nix
[
  {port = 443; destination = "192.168.50.20"; protocol = "tcp"; description = "HTTPS to the web server";}
]
```

The destination is the machine's **primary** address. `expose` is ignored (with a warning) while the host is
`standby` or `retired`, so a machine you switch off stops receiving traffic.

## Step 6: check, commit, deploy

```bash
nix run --inputs-from . fmf#fleet -- --check --device-leases 'network/devices/*-leases.nix'
git add -A && git commit -m "network: add nas and printer"
```

Then deploy the machine that **reads** the files (the gateway, or the DNS server). The machines you described do not
change.

```bash
nixos-rebuild switch --flake .#gateway --target-host admin@192.168.50.1
```

A new machine is now: one `host.nix`, `fleet`, commit, deploy the gateway. To fail the build when someone forgets
to run `fleet`, add the [drift check](FLEET-RUNBOOK.md#add-a-drift-check-to-ci).

## What was and was not tested

In a scratch downstream flake, `fleet` produced the files above, with and without a device lease file, and
rejected the error cases quoted here. The dnsmasq and NAT settings in A were evaluated (their values read back with
`nix eval`) and matched the records. **Not done:** deploying a gateway and handing out a lease to a real client.
B and C are the patterns that `blue-ridge` and Campground's `vm-adguard` use; B was evaluated in this repository
(`blue-ridge` reads its LAN leases and forwards that way); C was not run here.
