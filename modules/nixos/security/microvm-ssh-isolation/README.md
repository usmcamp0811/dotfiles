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
container DNS/NAT, dynamic table preservation across reloads, and initial guard
failure. They do not exercise production runners, live backend transitions, or
SSH credentials.
