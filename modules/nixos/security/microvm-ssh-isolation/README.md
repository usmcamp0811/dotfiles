---
type: NixOS Module
title: MicroVM SSH isolation
description: Filters guest-originated SSH at bridge ingress while preserving ordinary bridged traffic.
resource: ./default.nix
tags: [security, microvm, networking]
---

# MicroVM SSH isolation

`fmf.security.microvm-ssh-isolation` filters guest-originated traffic at the
hypervisor's Linux bridge TAP ingress. It does not rely on the guest's source
IP or MAC address. Both this module and `fmf.suites.microvm-host` are opt-in.

For a flake using fmf's Snowfall modules, enable the suite on a host:

```nix
fmf.suites.microvm-host.enable = true;
```

The suite discovers SSH ports from the consuming flake's physical
`nixosConfigurations` (using the `vm-` guest naming convention), plus port 22 and
the local host's configured SSH ports. Without flake inventory it uses port 22
and the local host's SSH ports. Additional ports can be supplied through
`fmf.security.microvm-ssh-isolation.sshPorts`.

The suite also discovers declared Linux bridges from systemd-networkd netdevs
and `networking.bridges`. On Docker hosts with local guest TAPs it supplies
these as `dockerBridgeInterfaces`. To use the security module directly, list
the guest LAN bridges explicitly, for example:

```nix
fmf.security.microvm-ssh-isolation.dockerBridgeInterfaces = ["br0"];
```

Docker's iptables backend can set `FORWARD DROP`, which also blocks ordinary
bridged VM traffic when bridge netfilter is enabled. The integration runs after
each Docker start/restart, linking `DOCKER-USER` to the owned
`FMF-MICROVM-BRIDGES` chain for IPv4 and IPv6. It accepts only same-bridge traffic
(`-i br0 -o br0` in this example). Other traffic returns to Docker's rules; the
FORWARD policy, Docker NAT, and unrelated rules are not changed. The native
bridge SSH guard still blocks prohibited SSH before this forwarding allowance.

The owned chain is rebuilt on Docker restart to remove stale bridge entries;
the owned jump is idempotent and other `DOCKER-USER` rules are retained. Bridge
configuration changes update Docker's post-start hook and can restart Docker
during activation, so plan around active containers. An empty list disables
this integration; Docker's native nftables backend and `iptables = false` are
not supported when the bridge list is nonempty.

Alternatively, enable only the security module and explicitly select ports:

```nix
fmf.security.microvm-ssh-isolation = {
  enable = true;
  sshPorts = [22 2222];
  exceptions = [{
    vm = "vm-recovery";
    destination = "192.0.2.1";
    ports = [22];
    reason = "Recovery jump host to its hypervisor";
  }];
};
```

No addresses, VM names, or exceptions are built into the modules. Each exception
identifies a declared guest's host-side TAPs and a literal destination, not a
spoofable source address. `family` defaults to `ip`; use `ip6` for IPv6.

## Requirements and limits

- The MicroVM host module must provide `microvm.vms`. Guests may be flake-backed,
  pre-evaluated, or inline configurations; non-autostart guests are included.
- Every declared guest interface must be a TAP attached to a Linux bridge.
  macvtap and other unsupported interface types fail assertions. Verify actual
  bridge membership after deployment; stale or imperatively launched runners
  are outside the declared inventory.
- Guest interfaces are access ports: guest-supplied VLAN tags are dropped.
- Guest-originated TCP to the selected SSH ports is dropped for IPv4 and IPv6,
  including guest-to-guest and external destinations unless excepted. Other
  service traffic and established reply-direction traffic remain unchanged.
- Host-to-guest SSH remains possible; guest SSH authentication settings are not
  modified. This is not a blanket established-connection exemption for existing
  guest-originated SSH sessions.
- The module loads bridge conntrack and owns only the
  `bridge fmf_microvm_ssh_isolation` table. It does **not** enable the global
  nftables service or switch the host firewall backend.
- Hosts already using nftables receive a named table in that service. For named
  rulesets, global ruleset flushing is disabled to preserve Docker's dynamically
  managed rules. Legacy complete rulesets remain under their owner's control.
- Other hosts use `microvm-ssh-isolation.service`, which atomically updates only
  the guard table. Reloads preserve unrelated rules; stopping this service leaves
  its rules installed. Use a reload, not a stop, to update the guard.
- Declared MicroVM services require successful startup of the selected guard
  service. Stopping that service can stop dependent guests. Migrating an older
  deployment from the global nftables dependency may also stop guests during
  activation: verify the guard, then check/restart affected guests deliberately.
- fmf's keepalived module selects its rule according to the active firewall
  backend rather than overwriting other firewall commands.

This is direct SSH-port isolation, not complete network segmentation. Other
service exploits, tunnels/overlays, arbitrary alternative SSH ports, and
shared-LAN ARP/NDP attacks require additional controls. Deploy first on a
non-critical host with console recovery; verify actual TAP membership, allowed
host-to-guest connections, denied guest-to-host connections, and service traffic.

## Test

From the fmf checkout, including untracked new files:

```bash
nix build --no-write-lock-file --no-link -L \
  'path:.#checks.x86_64-linux.microvm-ssh-isolation'
```

The isolated runtime tests exercise both original iptables and preexisting
nftables host backends, emulating TAP ingress with bridged veth namespaces.
They cover IPv4/IPv6, spoofing, interface-bound exceptions, host-initiated
traffic, non-SSH services, VLAN tags/fragments/extension headers, actual Docker
container DNS/NAT, dynamic table preservation across reloads, bridge-netfilter
with FORWARD DROP, post-start bridge-rule restoration after Docker restart,
foreign-rule preservation, and initial guard failure. IPv6's Docker-user
forwarding path is explicitly simulated in the test; IPv4 uses Docker's real
chains with an explicitly selected DROP policy. The tests do not exercise
production runners, live backend transitions, or SSH credentials.
