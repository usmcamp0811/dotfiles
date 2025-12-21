# Router Module Architecture

Complete architectural documentation for the Campground router modules.

## Table of Contents

- [Overview](#overview)
- [Module Hierarchy](#module-hierarchy)
- [Component Interactions](#component-interactions)
- [Network Stack](#network-stack)
- [Data Flow](#data-flow)
- [Service Dependencies](#service-dependencies)
- [Configuration Processing](#configuration-processing)
- [Firewall Architecture](#firewall-architecture)

## Overview

The Campground router is a modular NixOS-based router system designed to provide enterprise-grade routing and security features with the benefits of declarative configuration, atomic updates, and easy rollbacks.

### Design Principles

1. **Declarative Configuration** - All router settings are declared in Nix
2. **Modular Architecture** - Features are separated into independent modules
3. **Security by Default** - Secure defaults with opt-in for less secure options
4. **Zone-Based Isolation** - Network segmentation via VLANs and firewall zones
5. **Auditability** - All configuration changes tracked in version control

## Module Hierarchy

```
modules/nixos/router/
├── core/              # Core router functionality (WAN, LAN, NAT, DHCP, DNS)
├── security/          # Security hardening (SSH, fail2ban, kernel hardening)
├── zones/             # VLAN-based network segmentation
├── pentest-tools/     # Optional security testing tools
└── dhcp/              # (Disabled) Alternative DHCP implementation
```

### Module Responsibilities

#### Core Module (`core/default.nix`)

**Purpose:** Provides basic router functionality

**Responsibilities:**
- WAN interface configuration (DHCP or static)
- LAN bridge creation and configuration
- IP forwarding and routing
- NAT/masquerading
- DNS resolution (dnsmasq with DNSSEC)
- Basic firewall (nftables)
- Port forwarding

**Key Options:**
- `fmf.router.enable` - Enable router
- `fmf.router.wan.*` - WAN configuration
- `fmf.router.lan.*` - LAN configuration
- `fmf.router.dns.*` - DNS configuration
- `fmf.router.portForwards` - Port forwarding rules

**Services Managed:**
- `systemd-networkd` - Network interface management
- `dnsmasq` - DHCP and DNS server
- `nftables` - Firewall and NAT

#### Security Module (`security/default.nix`)

**Purpose:** Hardens the router against attacks

**Responsibilities:**
- SSH security hardening
- fail2ban integration
- Kernel security parameters
- Service minimization
- Audit logging
- Security monitoring tools

**Key Options:**
- `fmf.router.security.enable` - Enable security hardening
- `fmf.router.security.enableSSH` - Enable SSH
- `fmf.router.security.fail2ban.*` - fail2ban configuration

**Services Managed:**
- `sshd` - SSH server (LAN-only)
- `fail2ban` - Intrusion prevention
- `auditd` - Security audit daemon

#### Zones Module (`zones/default.nix`)

**Purpose:** VLAN-based network segmentation

**Responsibilities:**
- VLAN interface creation
- Per-zone DHCP configuration
- Zone-based firewall rules
- Inter-zone routing control
- DNS per zone

**Key Options:**
- `fmf.router.zones.enable` - Enable zones
- `fmf.router.zones.zones` - Zone definitions
- `fmf.router.zones.interZoneRoutes` - Inter-zone routing rules

**Services Managed:**
- `systemd-networkd` - VLAN interfaces
- `dnsmasq` - Per-zone DHCP and DNS

#### Pentest Tools Module (`pentest-tools/default.nix`)

**Purpose:** Optional security testing tools

**Responsibilities:**
- Install security testing scripts
- Provide testing documentation

**Key Options:**
- `fmf.router.pentest-tools.enable` - Install pentest tools

## Component Interactions

### Boot Sequence

```
1. systemd-networkd starts
   ↓
2. Creates br-lan bridge
   ↓
3. Creates VLAN interfaces (br-lan.10, br-lan.20, etc.)
   ↓
4. Assigns IP addresses to interfaces
   ↓
5. dnsmasq starts (DHCP + DNS)
   ↓
6. nftables loads firewall rules
   ↓
7. sshd starts (binds to br-lan IP)
   ↓
8. fail2ban starts (monitors SSH)
```

### Module Interaction Flow

```
┌─────────────────────────────────────────────────────┐
│                  User Configuration                  │
│            (systems/.../default.nix)                 │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│              Core Router Module                      │
│  • WAN/LAN interfaces                               │
│  • NAT/Masquerading                                 │
│  • Base firewall                                    │
│  • DHCP/DNS (dnsmasq)                               │
│  • Port forwarding                                  │
└────┬─────────────────────────┬──────────────────────┘
     │                         │
     ▼                         ▼
┌────────────────┐    ┌────────────────────────────┐
│ Security       │    │ Zones Module               │
│ Module         │    │  • VLAN interfaces         │
│  • SSH         │    │  • Per-zone DHCP           │
│  • fail2ban    │    │  • Zone firewall           │
│  • Kernel      │    │  • Inter-zone routing      │
│    hardening   │    └──────────┬─────────────────┘
└────────────────┘               │
                                 ▼
                    ┌─────────────────────────┐
                    │  Pentest Tools          │
                    │  (Optional)             │
                    └─────────────────────────┘
```

## Network Stack

### Interface Hierarchy

```
Physical Interfaces
├── enp1s0 (WAN)
│   └── IP: DHCP or static
│
└── enp2s0, enp3s0, enp4s0 (LAN ports)
    └── br-lan (bridge)
        ├── IP: 192.169.1.1 (LAN native)
        ├── br-lan.10 (VLAN 10 - WiFi)
        │   └── IP: 192.169.10.1
        ├── br-lan.20 (VLAN 20 - IoT)
        │   └── IP: 192.169.20.1
        └── br-lan.30 (VLAN 30 - Guest)
            └── IP: 192.169.30.1
```

### systemd-networkd Configuration

The core and zones modules generate systemd-networkd configurations:

**WAN Interface** (`20-wan.network`):
```nix
systemd.network.networks."20-wan" = {
  matchConfig.Name = "enp1s0";
  networkConfig.DHCP = "ipv4";
};
```

**LAN Bridge** (`10-br-lan.netdev`, `30-lan-bridge.network`):
```nix
systemd.network.netdevs."10-br-lan" = {
  netdevConfig = {
    Kind = "bridge";
    Name = "br-lan";
  };
};

systemd.network.networks."30-lan-bridge" = {
  matchConfig.Name = "br-lan";
  networkConfig.Address = "192.169.1.1/24";
};
```

**VLAN Interfaces** (`20-br-lan.10.netdev`, `40-br-lan.10.network`):
```nix
systemd.network.netdevs."20-br-lan.10" = {
  netdevConfig = {
    Kind = "vlan";
    Name = "br-lan.10";
  };
  vlanConfig.Id = 10;
};

systemd.network.networks."40-br-lan.10" = {
  matchConfig.Name = "br-lan.10";
  networkConfig.Address = "192.169.10.1/24";
};
```

## Data Flow

### Inbound Traffic (Internet → LAN)

```
Internet
  ↓
WAN (enp1s0)
  ↓
nftables PREROUTING (nat table)
  ├─→ DNAT (port forwarding rules)
  └─→ Original destination
       ↓
nftables FORWARD (filter table)
  ├─→ Established/Related: ACCEPT
  ├─→ Port forward rules: ACCEPT
  └─→ Default: DROP
       ↓
LAN/Zone Interface (br-lan, br-lan.10, etc.)
  ↓
Destination Host
```

### Outbound Traffic (LAN → Internet)

```
LAN Device
  ↓
LAN/Zone Interface (br-lan, br-lan.10, etc.)
  ↓
nftables FORWARD (filter table)
  ├─→ Zone → WAN allowed: ACCEPT
  └─→ Otherwise: DROP
       ↓
nftables POSTROUTING (nat table)
  └─→ MASQUERADE (source NAT)
       ↓
WAN (enp1s0)
  ↓
Internet
```

### Inter-Zone Traffic (WiFi → LAN)

```
WiFi Device (192.169.10.x)
  ↓
br-lan.10 (WiFi zone)
  ↓
nftables FORWARD (zones table, priority 1)
  ├─→ Established/Related: ACCEPT
  ├─→ Inter-zone route exists: ACCEPT
  │   └─→ Port/protocol restrictions applied
  ├─→ Isolation level "partial": ACCEPT (LAN only)
  ├─→ Isolation level "none": ACCEPT (all zones)
  └─→ Default: DROP
       ↓
br-lan (LAN zone)
  ↓
LAN Device (192.169.1.x)
```

### DNS Resolution Flow

#### Standard Configuration (Router DNS)

```
Client (DHCP)
  ↓ (Gets DNS server = 192.169.1.1)
Router dnsmasq (192.169.1.1:53)
  ↓ (Forwards to upstream)
Upstream DNS (1.1.1.1, 1.0.0.1, etc.)
  ↓
Response → dnsmasq → Client
```

#### AdGuard Configuration

```
Client (DHCP)
  ↓ (Gets DNS server = 192.169.1.30)
AdGuard Home (192.169.1.30:53)
  ↓ (Filtering, blocking)
  ↓ (Forwards to upstream)
Upstream DNS (1.1.1.1, 1.0.0.1, etc.)
  ↓
Response → AdGuard → Client
```

## Service Dependencies

### Critical Path Dependencies

```
systemd-networkd.service
  ↓ (creates network interfaces)
network-online.target
  ↓
dnsmasq.service (DHCP + DNS)
  ↓
nftables.service (firewall)
  ↓
sshd.service (management access)
  ↓
fail2ban.service (SSH protection)
```

### Startup Timing

The modules include explicit service dependencies to ensure correct startup order:

**dnsmasq** (`core/default.nix:315-327`):
```nix
systemd.services.dnsmasq = {
  after = [
    "systemd-networkd.service"
    "network-online.target"
  ];
  wants = ["network-online.target"];
  serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
};
```

**sshd** (`security/default.nix:103-115`):
```nix
systemd.services.sshd = {
  after = [
    "systemd-networkd.service"
    "network-online.target"
  ];
  wants = ["network-online.target"];
  serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
};
```

The 2-second delay ensures VLAN interfaces are fully initialized before services bind to them.

## Configuration Processing

### Nix Evaluation Flow

```
User Config (systems/.../default.nix)
  ↓
fmf.router.* options set
  ↓
Core module (core/default.nix)
  ├─→ Generates systemd-networkd configs
  ├─→ Generates dnsmasq settings
  └─→ Generates nftables ruleset (base)
       ↓
Zones module (zones/default.nix)
  ├─→ Generates VLAN netdevs
  ├─→ Extends dnsmasq settings
  └─→ Extends nftables ruleset (zone rules)
       ↓
Security module (security/default.nix)
  ├─→ Configures SSH
  ├─→ Configures fail2ban
  └─→ Sets kernel parameters
       ↓
Final NixOS configuration
  ↓
nixos-rebuild
  ↓
Running system
```

### Port Forward Generation

The core module generates nftables rules from the declarative `portForwards` option:

**User Configuration:**
```nix
fmf.router.portForwards = [
  {
    port = 443;
    destination = "192.169.1.100";
    protocol = "tcp";
    description = "HTTPS to web server";
  }
];
```

**Generated NAT Rule** (`core/default.nix:12-21`):
```nft
# HTTPS to web server
iifname "enp1s0" tcp dport 443 dnat to 192.169.1.100:443
```

**Generated Filter Rule** (`core/default.nix:24-33`):
```nft
# HTTPS to web server
iifname "enp1s0" oifname "br-lan" ip daddr 192.169.1.100 meta l4proto tcp th dport 443 ct state new accept
```

### Inter-Zone Route Generation

The zones module generates nftables rules from `interZoneRoutes`:

**User Configuration:**
```nix
fmf.router.zones.interZoneRoutes = [
  {
    from = "iot";
    to = ["lan"];
    protocol = "tcp";
    ports = [8123];
    destinationIPs = ["192.169.1.100"];
    description = "IoT to Home Assistant";
  }
];
```

**Generated Rule** (`zones/default.nix:24-73`):
```nft
# IoT to Home Assistant
iifname "br-lan.20" oifname "br-lan" ip daddr 192.169.1.100 meta l4proto tcp th dport 8123 accept
```

## Firewall Architecture

### nftables Table Structure

The router uses multiple nftables tables for different purposes:

```
inet filter (core module)
  ├── chain input (policy: drop)
  │   ├── Accept established/related
  │   ├── Accept loopback
  │   ├── Accept from LAN
  │   └── Accept DHCP/DNS
  └── chain forward (policy: drop)
      ├── Accept established/related
      ├── Accept LAN → WAN
      └── Accept port forwards

ip nat (core module)
  ├── chain prerouting
  │   └── DNAT for port forwards
  └── chain postrouting
      └── MASQUERADE for WAN

inet zones (zones module, priority 1)
  ├── chain input (policy: accept)
  │   └── Accept all zones to router services
  └── chain forward (policy: drop)
      ├── Accept established/related
      ├── Accept WAN → LAN (port forwards)
      ├── Accept zone → WAN (if allowed)
      ├── Accept inter-zone routes
      └── Enforce isolation levels
```

### Rule Priority

nftables processes chains by priority:

1. **Priority 0** (core/default.nix): Base firewall rules
2. **Priority 1** (zones/default.nix): Zone-based rules

The zones table has priority 1, so it processes packets after the base filter table. This allows zone rules to override or extend base rules.

### Firewall Rule Generation

**Base Firewall** (core module):
```nix
networking.nftables.ruleset = ''
  table inet filter {
    chain input {
      type filter hook input priority 0; policy drop;
      ct state { established, related } accept
      iifname "lo" accept
      iifname "${cfg.lan.bridgeName}" accept
      udp dport {67, 68} accept
      tcp dport 53 accept
      udp dport 53 accept
    }
    chain forward {
      type filter hook forward priority 0; policy drop;
      ct state { established, related } accept
      iifname "${cfg.lan.bridgeName}" oifname "${cfg.wan.interface}" accept
      ${mkPortForwardFilterRules cfg.portForwards}
    }
  }
  table ip nat {
    chain prerouting {
      type nat hook prerouting priority -100;
      ${mkPortForwardNatRules cfg.portForwards}
    }
    chain postrouting {
      type nat hook postrouting priority 100;
      oifname "${cfg.wan.interface}" masquerade
    }
  }
'';
```

**Zone Firewall** (zones module, extends with `mkAfter`):
```nix
networking.nftables.ruleset = mkAfter ''
  table inet zones {
    chain forward {
      type filter hook forward priority 1; policy drop;
      ct state { established, related } accept

      # Zone → WAN
      ${mkZoneToWanRules}

      # Inter-zone routes
      ${mkInterZoneRules}

      # Isolation enforcement
      ${isolationRules}
    }
  }
'';
```

## State Management

### Stateful Services

**dnsmasq DHCP leases:**
- File: `/var/lib/dnsmasq/dnsmasq.leases`
- Format: Timestamp, MAC, IP, Hostname, Client-ID
- Persists across reboots

**fail2ban banned IPs:**
- Database: In-memory (nftables sets)
- Logs: `/var/log/fail2ban.log`
- Does NOT persist across reboots (by design)

**nftables connection tracking:**
- In-kernel state (conntrack)
- Tracks established connections
- Does NOT persist across reboots

### Configuration Files

All configuration is declarative and stored in `/etc/nixos` or `/config`:

- Router config: `/config/systems/x86_64-linux/blueridge/default.nix`
- Module source: `/config/modules/nixos/router/*`
- Generated configs: `/etc/systemd/network/*`, `/etc/nftables.conf`, `/etc/dnsmasq.conf`

## Performance Considerations

### dnsmasq

- Lightweight, minimal memory footprint
- Handles both DHCP and DNS
- Caches DNS queries (default: 150 entries)
- No significant tuning required for home router use

### nftables

- Modern replacement for iptables
- Better performance with large rulesets
- Uses nftables sets for zone subnets (O(1) lookup)
- Connection tracking in kernel

### systemd-networkd

- Fast, minimal network configuration daemon
- Native VLAN support
- No Python/heavy dependencies

## Security Architecture

### Defense in Depth

The router implements multiple layers of security:

1. **Perimeter (WAN)**
   - Default deny firewall
   - No services exposed (except port forwards)
   - SYN flood protection
   - Martian packet filtering

2. **Network Layer (Zones)**
   - VLAN isolation
   - Zone-based firewall
   - Least-privilege inter-zone routing

3. **Host Layer (Router)**
   - SSH LAN-only
   - fail2ban intrusion prevention
   - Kernel hardening
   - Audit logging

4. **Service Layer**
   - Minimal services
   - Modern SSH ciphers only
   - DNSSEC validation

### Attack Surface Reduction

**Disabled Services:**
- Avahi (mDNS)
- CUPS (printing)
- PulseAudio
- X server
- Most desktop services

**Restricted Services:**
- SSH: LAN-only, key-based auth, modern ciphers
- DNS: Recursive queries allowed from LAN/zones only
- DHCP: Bound to LAN/zone interfaces only

### Kernel Hardening

Applied by security module (`security/default.nix:146-169`):

```nix
boot.kernel.sysctl = {
  # Disable IPv6 (not supported)
  "net.ipv6.conf.all.disable_ipv6" = 1;

  # Kernel hardening
  "kernel.kptr_restrict" = 2;           # Hide kernel pointers
  "kernel.dmesg_restrict" = 1;          # Restrict dmesg
  "kernel.unprivileged_bpf_disabled" = 1;  # Disable unprivileged BPF
  "net.core.bpf_jit_harden" = 2;        # Harden BPF JIT

  # Network hardening (inherited from fmf.router)
  "net.ipv4.conf.all.rp_filter" = 1;    # Anti-spoofing
  "net.ipv4.conf.all.accept_redirects" = 0;
  "net.ipv4.conf.all.send_redirects" = 0;
  "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
  "net.ipv4.tcp_syncookies" = 1;        # SYN flood protection
  "net.ipv4.tcp_rfc1337" = 1;           # TIME-WAIT assassination protection

  # Logging
  "net.ipv4.conf.all.log_martians" = 1;
};
```

## Debugging and Observability

### Log Locations

- **System logs**: `journalctl`
- **dnsmasq**: `journalctl -u dnsmasq`
- **nftables**: `journalctl -u nftables`
- **SSH**: `journalctl -u sshd`
- **fail2ban**: `journalctl -u fail2ban`, `/var/log/fail2ban.log`

### Diagnostic Commands

**Network interfaces:**
```bash
ip link show
ip addr show
networkctl status
```

**DHCP leases:**
```bash
cat /var/lib/dnsmasq/dnsmasq.leases
```

**Firewall rules:**
```bash
nft list ruleset
nft list table inet filter
nft list table inet zones
nft list table ip nat
```

**Connection tracking:**
```bash
conntrack -L
```

**DNS testing:**
```bash
dig @192.169.1.1 example.com
nslookup example.com 192.169.1.1
```

### Helper Scripts

The modules provide diagnostic scripts:

- `router-security-check` (security module) - Security status overview
- `router-zones` (zones module) - Zone configuration summary

## Extension Points

### Adding New Modules

New modules can extend the router by:

1. Creating a new directory: `modules/nixos/router/mymodule/`
2. Adding `default.nix` with module definition
3. Using `fmf.router.mymodule` namespace
4. Depending on `routerCfg.enable`

Example skeleton:

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.router.mymodule;
  routerCfg = config.fmf.router;
in {
  options.fmf.router.mymodule = {
    enable = mkEnableOption "My router module" // {default = routerCfg.enable;};
    # ... other options
  };

  config = mkIf (routerCfg.enable && cfg.enable) {
    # ... configuration
  };
}
```

### Extending Firewall Rules

Firewall rules can be extended in multiple ways:

1. **Core module**: `fmf.router.firewall.extraRules`
2. **Zones module**: `fmf.router.zones.extraFirewallRules`
3. **Direct**: `networking.nftables.ruleset = mkAfter "..."`

### Extending dnsmasq

dnsmasq settings can be extended:

```nix
services.dnsmasq.settings = {
  # Your custom dnsmasq options
  address = ["/local.domain/192.168.1.100"];
};
```

This merges with the router module's dnsmasq configuration.

## Future Architecture Considerations

### Potential Enhancements

1. **IPv6 Support**
   - Currently disabled in security module
   - Would require firewall rules, DHCPv6, IPv6 NAT/routing

2. **VPN Support**
   - WireGuard integration
   - OpenVPN server
   - Site-to-site VPN

3. **QoS/Traffic Shaping**
   - Per-zone bandwidth limits
   - Traffic prioritization

4. **Web UI**
   - LuCI-style management interface
   - Real-time monitoring dashboard

5. **High Availability**
   - VRRP for router failover
   - Redundant WAN connections

### Scalability Limits

Current architecture is designed for:
- **Small to medium deployments** (< 100 devices)
- **Up to 10 zones** (more would require careful firewall optimization)
- **Home/small office** use cases

For larger deployments, consider:
- Hardware acceleration (NICs with offload support)
- More powerful CPU for firewall processing
- Dedicated DNS/DHCP servers instead of dnsmasq
