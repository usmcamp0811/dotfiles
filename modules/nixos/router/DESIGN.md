# Router Module Design Decisions

Documentation of design decisions, rationale, and trade-offs for the Campground router modules.

## Table of Contents

- [Core Design Principles](#core-design-principles)
- [Technology Choices](#technology-choices)
- [Module Organization](#module-organization)
- [Network Architecture Decisions](#network-architecture-decisions)
- [Security Design](#security-design)
- [Performance Considerations](#performance-considerations)
- [Trade-offs and Limitations](#trade-offs-and-limitations)
- [Alternatives Considered](#alternatives-considered)
- [Future Considerations](#future-considerations)

---

## Core Design Principles

### 1. Declarative Over Imperative

**Decision:** All router configuration is declarative using Nix.

**Rationale:**
- **Reproducibility**: Identical configuration produces identical results
- **Version Control**: All changes tracked in Git
- **Atomic Updates**: Changes applied atomically via `nixos-rebuild`
- **Rollbacks**: Easy rollback to previous configurations
- **Documentation**: Configuration serves as documentation

**Alternative Considered:** Traditional imperative scripts (like OpenWRT's UCI)

**Why Not:** Imperative configurations drift over time, are hard to reproduce, and lack atomic update guarantees.

### 2. Modular Architecture

**Decision:** Features separated into independent, composable modules (core, security, zones, pentest-tools).

**Rationale:**
- **Separation of Concerns**: Each module has a single responsibility
- **Optional Features**: Users can enable only what they need
- **Maintainability**: Changes to one module don't affect others
- **Extensibility**: New modules can be added without modifying existing ones

**Example:**
```nix
fmf.router.enable = true;           # Core functionality
fmf.router.security.enable = true;  # Optional security hardening
fmf.router.zones.enable = true;     # Optional VLAN zones
```

### 3. Security by Default

**Decision:** Secure defaults with opt-in for less secure options.

**Rationale:**
- **Fail-Safe**: Default configuration is secure even if user doesn't customize
- **Principle of Least Privilege**: Only necessary access is granted by default
- **Explicit Unsafe**: Insecure options require explicit user action

**Examples:**
- SSH is LAN-only by default
- WAN ping is disabled by default
- Firewall default policy is DROP
- Zone isolation is FULL by default

### 4. Explicit Over Implicit

**Decision:** All configuration options are explicit and well-documented.

**Rationale:**
- **Clarity**: No hidden behavior or magic defaults
- **Predictability**: Users know exactly what will happen
- **Debugging**: Easy to trace configuration to behavior

**Example:**
```nix
# Explicit route with all details
{
  from = "iot";
  to = ["lan"];
  protocol = "tcp";
  ports = [8123];
  destinationIPs = ["192.169.1.100"];
  description = "IoT to Home Assistant";
}
```

### 5. Composability

**Decision:** Modules extend each other using Nix's module system.

**Rationale:**
- **No Conflicts**: Modules can coexist without interference
- **Incremental Adoption**: Users can add features incrementally
- **Extension Points**: New functionality can extend existing modules

**Example:**
```nix
# Zones module extends core firewall
networking.nftables.ruleset = mkAfter ''
  # Zone rules added after core rules
'';
```

---

## Technology Choices

### systemd-networkd

**Decision:** Use systemd-networkd for network interface management.

**Rationale:**
- **Native VLAN Support**: Built-in VLAN creation and management
- **Lightweight**: No heavy dependencies
- **Integration**: Well-integrated with systemd and NixOS
- **Declarative**: Configuration via `.network` and `.netdev` files
- **Reliable**: Battle-tested in production environments

**Alternative Considered:** NetworkManager, ifupdown, custom scripts

**Why Not:**
- **NetworkManager**: Too heavy for a router, designed for desktops
- **ifupdown**: Legacy, not declarative
- **Custom scripts**: Error-prone, hard to maintain

### dnsmasq

**Decision:** Use dnsmasq for DHCP and DNS.

**Rationale:**
- **All-in-One**: Combines DHCP and DNS in one lightweight daemon
- **Low Memory**: Minimal resource usage (< 10MB RAM)
- **DNSSEC Support**: Built-in DNSSEC validation
- **Battle-Tested**: Used in OpenWRT, DD-WRT, and many embedded routers
- **Simple Configuration**: Easy to configure declaratively
- **Per-Interface DHCP**: Can serve DHCP on multiple VLANs

**Alternative Considered:** ISC Kea + Unbound, systemd-resolved

**Why Not:**
- **Kea + Unbound**: More complex, higher memory usage, two services instead of one
- **systemd-resolved**: Not designed for DHCP server role

**Note:** A Kea-based DHCP module exists in `dhcp/default.nix.disabled` but is not used because:
1. dnsmasq is simpler for combined DHCP+DNS
2. Kea requires separate DNS server
3. Kea has larger memory footprint

### nftables

**Decision:** Use nftables for firewall and NAT.

**Rationale:**
- **Modern**: Replacement for iptables (deprecated)
- **Performance**: Better performance with large rulesets
- **Syntax**: More readable and consistent syntax
- **Sets**: Native support for IP sets (used for zone subnets)
- **Single Tool**: Replaces iptables, ip6tables, arptables, ebtables
- **Atomic Updates**: Ruleset loaded atomically

**Alternative Considered:** iptables, firewalld

**Why Not:**
- **iptables**: Legacy, deprecated, worse performance
- **firewalld**: Too high-level, less flexible for custom rules

### Bridges Instead of Routing

**Decision:** Use Linux bridge (br-lan) for LAN instead of routing between interfaces.

**Rationale:**
- **Layer 2 Switching**: Devices on same subnet can communicate directly without router
- **Performance**: Hardware switching on switch, not routing in router
- **VLAN Support**: Bridge natively supports VLAN tagging
- **Simplicity**: All LAN ports appear as single network

**Alternative Considered:** Routing between interfaces

**Why Not:** Routing would require:
- Separate subnet per physical port
- All traffic goes through router (bottleneck)
- More complex configuration

---

## Module Organization

### Why Separate Modules?

**Decision:** Split functionality into `core`, `security`, `zones`, and `pentest-tools` modules.

**Rationale:**

**Core Module:**
- **Single Responsibility**: Basic router functionality only
- **Minimal Dependencies**: Can work standalone
- **Foundation**: Other modules build on core

**Security Module:**
- **Optional Hardening**: Users can disable if needed
- **Separation of Concerns**: Security logic separate from routing logic
- **Reusable**: Security settings could apply to non-router hosts

**Zones Module:**
- **Advanced Feature**: Not all users need VLANs
- **Complexity**: Zone firewall logic is complex, better isolated
- **Optional**: Core router works without zones

**Pentest-Tools Module:**
- **Development Only**: Not for production
- **Security Testing**: Install security testing tools
- **Clearly Optional**: Disabled by default

### Module Interaction

**Decision:** Modules use `mkIf (routerCfg.enable && cfg.enable)` pattern.

**Rationale:**
- **Automatic Activation**: Modules enable when router is enabled
- **Manual Override**: User can explicitly disable a module
- **Clear Dependencies**: Module depends on core router

**Example:**
```nix
config = mkIf (routerCfg.enable && cfg.enable) {
  # Module configuration only applied if both router and module are enabled
};
```

---

## Network Architecture Decisions

### VLAN Strategy: Tagged VLANs on Bridge

**Decision:** Use VLAN tagging on the LAN bridge with one native (untagged) VLAN.

**Rationale:**
- **Backward Compatibility**: Devices on native VLAN don't need VLAN support
- **Flexibility**: Tagged VLANs can be added/removed without physical changes
- **Switch Configuration**: Matches typical managed switch setup
- **Scalability**: Supports up to 4094 VLANs (theoretical)

**Architecture:**
```
br-lan (bridge)
├── No VLAN tag: Native VLAN (lan)
├── VLAN 10: WiFi
├── VLAN 20: IoT
└── VLAN 30: Guest
```

**Alternative Considered:** Separate physical interface per network

**Why Not:**
- Requires more physical ports
- Wastes hardware
- Less flexible

### Zone Isolation Levels

**Decision:** Three isolation levels: `full`, `partial`, `none`.

**Rationale:**
- **full**: For untrusted networks (IoT, Guest)
- **partial**: For semi-trusted networks (WiFi)
- **none**: For trusted networks (LAN)

**Why Three Levels:**
- **Simplicity**: Three levels cover most use cases
- **Clarity**: Easy to understand
- **Balance**: Not too complex, not too limiting

**Alternative Considered:** Binary isolation (isolated or not)

**Why Not:** Doesn't handle semi-trusted WiFi case well.

### Inter-Zone Routes: Declarative Rules

**Decision:** Explicit `interZoneRoutes` list with granular control.

**Rationale:**
- **Explicit Security**: Every allowed route is declared
- **Least Privilege**: Only necessary routes are added
- **Documentation**: Routes serve as documentation
- **Auditability**: Easy to review all inter-zone access

**Example:**
```nix
interZoneRoutes = [
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

**Alternative Considered:** Automatic partial access based on isolation level

**Why Not:**
- Implicit behavior is harder to audit
- Users might not realize what access is allowed
- Less flexible

### DNS Architecture

**Decision:** Support both router DNS and external DNS (AdGuard).

**Rationale:**
- **Flexibility**: Users can choose their DNS setup
- **Simple Case**: Router DNS works out-of-the-box
- **Advanced Case**: AdGuard for centralized filtering

**How It Works:**
1. **Router DNS**: `dns.forwarders = ["1.1.1.1"]` - router forwards to public DNS
2. **AdGuard DNS**: `dns.forwarders = ["192.169.1.30"]` - router forwards to AdGuard

**Per-Zone DNS:**
- Zones can specify custom DNS via `dns.servers`
- DHCP advertises the specified DNS servers to clients

**Alternative Considered:** Only support router DNS

**Why Not:** Users want AdGuard for centralized filtering across all zones.

---

## Security Design

### Firewall Default Policy: DROP

**Decision:** Default firewall policy is DROP (deny all, allow explicitly).

**Rationale:**
- **Secure by Default**: Unknown traffic is blocked
- **Fail-Safe**: If rules fail to load, nothing is allowed
- **Best Practice**: Industry standard for security

**Alternative Considered:** Default ACCEPT (allow all, block explicitly)

**Why Not:** Dangerous, one missed rule could expose the network.

### SSH: LAN-Only by Default

**Decision:** SSH listens only on LAN interface by default.

**Rationale:**
- **Attack Surface Reduction**: SSH not exposed to internet
- **Brute Force Protection**: WAN attackers can't reach SSH
- **Explicit Unsafe**: User must explicitly enable WAN SSH

**Configuration:**
```nix
services.openssh.settings.ListenAddress = routerCfg.lan.gateway;
```

**Alternative Considered:** SSH on all interfaces

**Why Not:** Exposes SSH to internet by default (dangerous).

### fail2ban Integration

**Decision:** Enable fail2ban by default for SSH.

**Rationale:**
- **Defense in Depth**: Even LAN-only SSH benefits from brute force protection
- **Zero Configuration**: Works out-of-the-box
- **Lightweight**: Minimal performance impact

**Alternative Considered:** No fail2ban, rely on firewall

**Why Not:** Firewall doesn't protect against brute force from inside LAN.

### Kernel Hardening

**Decision:** Apply comprehensive kernel hardening via sysctl.

**Rationale:**
- **Defense in Depth**: Multiple layers of security
- **Best Practices**: Based on industry recommendations
- **Low Cost**: No performance impact for most parameters

**Key Settings:**
```nix
"kernel.kptr_restrict" = 2;              # Hide kernel pointers
"kernel.unprivileged_bpf_disabled" = 1;  # Disable unprivileged BPF
"net.ipv4.tcp_syncookies" = 1;           # SYN flood protection
"net.ipv4.conf.all.rp_filter" = 1;       # Anti-spoofing
```

### Port Forwarding Security

**Decision:** Port forwards are explicit with description field.

**Rationale:**
- **Documentation**: Each forward has a description
- **Auditability**: Easy to review all exposed ports
- **Explicit**: No automatic port forwarding (unlike UPnP)

**Example:**
```nix
{
  port = 443;
  destination = "192.168.1.100";
  protocol = "tcp";
  description = "HTTPS to web server";  # Required for documentation
}
```

**Alternative Considered:** UPnP (automatic port forwarding)

**Why Not:** Security risk, devices can open ports without user knowledge.

---

## Performance Considerations

### Service Startup Delays

**Decision:** Add 2-second delay before starting dnsmasq and sshd.

**Rationale:**
- **Race Condition**: VLAN interfaces may not be fully up when service starts
- **Bind Failures**: Service fails if IP address not yet assigned
- **Reliability**: Small delay ensures stable startup

**Implementation:**
```nix
systemd.services.dnsmasq = {
  after = ["systemd-networkd.service" "network-online.target"];
  wants = ["network-online.target"];
  serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
};
```

**Alternative Considered:** systemd dependencies only (no delay)

**Why Not:** `network-online.target` doesn't guarantee VLAN IPs are assigned.

### nftables: Sets for Zone Subnets

**Decision:** Use nftables sets for zone subnet matching.

**Rationale:**
- **Performance**: O(1) lookup instead of O(n)
- **Scalability**: Efficient even with many zones
- **Readability**: Cleaner ruleset

**Implementation:**
```nft
set iot_nets {
  type ipv4_addr
  flags interval
  elements = { 192.169.20.0/24 }
}

# Then match with:
ip saddr @iot_nets
```

**Alternative Considered:** Direct IP matching in rules

**Why Not:** Less efficient, more verbose.

### Connection Tracking

**Decision:** Use stateful connection tracking (`ct state {established, related}`).

**Rationale:**
- **Performance**: Established connections skip most rules
- **Security**: Only NEW connections are evaluated
- **Simplicity**: Eliminates need for separate return traffic rules

**Example:**
```nft
ct state { established, related } accept  # Fast path
# Only new connections evaluated below
```

---

## Trade-offs and Limitations

### IPv6: Not Supported

**Decision:** IPv6 is explicitly disabled.

**Rationale:**
- **Complexity**: IPv6 NAT, DHCPv6, and firewall rules add significant complexity
- **Testing**: Harder to test and debug
- **Use Case**: Most home networks don't require IPv6

**Trade-off:**
- **Pro**: Simpler configuration, easier to secure
- **Con**: No IPv6 support for networks that need it

**Future:** Could be added as optional module.

### No Web UI

**Decision:** No web-based management interface.

**Rationale:**
- **Security**: Web UI is an attack surface
- **Simplicity**: Declarative config is the interface
- **Consistency**: All config in version control

**Trade-off:**
- **Pro**: More secure, fully declarative
- **Con**: Less user-friendly for non-technical users

**Alternative:** SSH + CLI tools (provided: `router-security-check`, `router-zones`).

### dnsmasq DHCP per Zone

**Decision:** dnsmasq serves DHCP on all zones (not just LAN).

**Rationale:**
- **Simplicity**: One DHCP server for all zones
- **Lightweight**: dnsmasq is very efficient
- **Per-Zone Config**: Supports per-zone DHCP options

**Trade-off:**
- **Pro**: Simple, low resource usage
- **Con**: If dnsmasq fails, all zones lose DHCP

**Alternative:** Separate DHCP server per zone (e.g., AdGuard for LAN, dnsmasq for others).

### Static Leases: Per-Zone Only

**Decision:** Static leases are configured per zone, not globally.

**Rationale:**
- **Clarity**: Lease belongs to specific zone
- **Organization**: Easier to manage zone-specific devices

**Trade-off:**
- **Pro**: Clear organization
- **Con**: Can't have one global static lease config

### Zone Firewall: Priority 1

**Decision:** Zone firewall rules use priority 1 (after core rules at priority 0).

**Rationale:**
- **Layering**: Core rules apply first, zone rules refine
- **Port Forwarding**: Core port forwards are allowed before zone restrictions

**Example:**
```
Priority 0 (core): Allow WAN → LAN port forwards
Priority 1 (zones): Apply zone isolation rules
```

**Trade-off:**
- **Pro**: Core and zone rules don't conflict
- **Con**: Ordering can be confusing if not documented

---

## Alternatives Considered

### Alternative 1: OpenWRT-Based Router

**Considered:** Use OpenWRT instead of NixOS.

**Pros:**
- Purpose-built for routers
- Large community
- Many pre-built packages
- Web UI (LuCI)

**Cons:**
- Imperative configuration (UCI)
- No atomic updates
- No rollbacks
- Harder to version control
- Less flexible

**Decision:** NixOS chosen for declarative config and reproducibility.

### Alternative 2: pfSense/OPNsense

**Considered:** Use pfSense or OPNsense.

**Pros:**
- Feature-rich web UI
- Active development
- Good community

**Cons:**
- FreeBSD-based (less familiar)
- Imperative configuration
- XML-based config (hard to manage in Git)
- Heavier resource usage
- Less flexible than NixOS

**Decision:** NixOS chosen for declarative config and better control.

### Alternative 3: VyOS

**Considered:** Use VyOS (Debian-based router OS).

**Pros:**
- Declarative config (CLI)
- Familiar to network engineers (Vyatta/JunOS-like)

**Cons:**
- Not as declarative as Nix
- No rollback mechanism
- Smaller community
- Less flexible

**Decision:** NixOS chosen for better declarative config.

### Alternative 4: NetworkManager for Network Management

**Considered:** Use NetworkManager instead of systemd-networkd.

**Pros:**
- User-friendly
- Good desktop integration

**Cons:**
- Too heavy for a router (D-Bus, GUI dependencies)
- Designed for laptops, not servers/routers
- Less declarative

**Decision:** systemd-networkd chosen for lightweight and declarative config.

### Alternative 5: Separate DHCP Server per Zone

**Considered:** Run separate DHCP server (e.g., Kea) for each zone.

**Pros:**
- Isolated failure domains
- More flexible per-zone configuration

**Cons:**
- Higher resource usage
- More complex configuration
- More services to manage

**Decision:** Single dnsmasq instance chosen for simplicity.

---

## Future Considerations

### IPv6 Support

**Consideration:** Add optional IPv6 module.

**Challenges:**
- IPv6 firewall rules
- DHCPv6 vs SLAAC
- IPv6 NAT (if needed)
- Testing complexity

**Approach:**
```nix
fmf.router.ipv6 = {
  enable = true;
  mode = "dhcpv6";  # or "slaac" or "static"
};
```

### VPN Module

**Consideration:** Add WireGuard/OpenVPN module.

**Features:**
- Declarative VPN peer configuration
- Automatic firewall rules
- DNS integration

**Approach:**
```nix
fmf.router.vpn = {
  enable = true;
  type = "wireguard";
  listenPort = 51820;
  peers = [ ... ];
};
```

### QoS/Traffic Shaping

**Consideration:** Add traffic shaping module.

**Features:**
- Per-zone bandwidth limits
- Traffic prioritization
- Application-based QoS

**Approach:**
```nix
fmf.router.qos = {
  enable = true;
  zones = {
    guest.maxBandwidth = "10Mbps";
  };
};
```

### Web UI Module (Optional)

**Consideration:** Add optional web-based management UI.

**Requirements:**
- Read-only dashboard (don't modify config)
- Real-time monitoring
- Log viewing
- Security: LAN-only, HTTPS

**Approach:**
```nix
fmf.router.webui = {
  enable = true;
  port = 8443;
  lanOnly = true;
};
```

### High Availability

**Consideration:** Add VRRP for router redundancy.

**Features:**
- Two routers (master + backup)
- Automatic failover
- Shared virtual IP

**Challenges:**
- State synchronization (DHCP leases, conntrack)
- Configuration consistency
- Testing complexity

### VLAN Trunking to WiFi AP

**Consideration:** Document VLAN trunking to WiFi AP.

**Approach:**
- Configure AP as trunk port
- Map SSIDs to VLANs
- Document setup for common APs (UniFi, TP-Link, etc.)

### Dynamic DNS

**Consideration:** Add DDNS module for dynamic WAN IP.

**Approach:**
```nix
fmf.router.ddns = {
  enable = true;
  provider = "cloudflare";
  domain = "home.example.com";
  tokenFile = "/etc/ddns/token";
};
```

---

## Lessons Learned

### 1. Start Simple, Add Complexity

**Lesson:** Core module started simple (WAN, LAN, NAT, firewall). Advanced features (zones, security) added later.

**Takeaway:** Incremental complexity is easier to manage than building everything at once.

### 2. Explicit is Better Than Implicit

**Lesson:** Explicit `interZoneRoutes` are clearer than automatic routing based on isolation level.

**Takeaway:** Users prefer explicit configuration they can understand and audit.

### 3. Service Dependencies Are Hard

**Lesson:** systemd dependencies and `network-online.target` are not enough to ensure VLAN IPs are assigned.

**Takeaway:** Sometimes a small delay is the most reliable solution.

### 4. Documentation is Configuration

**Lesson:** Requiring `description` field for port forwards and inter-zone routes improves documentation.

**Takeaway:** Make documentation part of the configuration, not separate.

### 5. Defaults Matter

**Lesson:** Secure defaults (LAN-only SSH, fail2ban enabled, isolation = full) prevent security mistakes.

**Takeaway:** Design for the least-secure user, make it easy to do the right thing.

---

## Conclusion

The Campground router modules are designed with the following priorities:

1. **Security First**: Secure by default, explicit opt-in for unsafe options
2. **Declarative**: All configuration in Nix, version controlled
3. **Modular**: Features separated into composable modules
4. **Flexible**: Supports simple single-LAN and complex multi-zone setups
5. **Reliable**: Atomic updates, easy rollbacks

The design balances:
- **Simplicity** vs **Flexibility**: Simple defaults, advanced features optional
- **Security** vs **Usability**: Secure by default, but not locked down
- **Performance** vs **Features**: Lightweight, but feature-rich

Future enhancements (IPv6, VPN, QoS, Web UI) can be added incrementally without breaking existing functionality.
