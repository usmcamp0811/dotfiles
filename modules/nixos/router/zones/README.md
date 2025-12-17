# Network Zones Module

VLAN-based network segmentation with zone-based firewall for the Campground router.

## Overview

The zones module allows you to create isolated network segments (zones) using VLANs, each with its own subnet, DHCP, DNS, and firewall rules. This is perfect for separating different types of devices (trusted LAN, WiFi, IoT, guests) while maintaining fine-grained control over inter-zone communication.

## Features

- **VLAN-based segmentation**: Each zone can have its own VLAN ID
- **Per-zone DHCP/DNS**: Automatic DHCP and DNS configuration for each zone
- **Zone-based firewall**: Isolation levels (full, partial, none) with explicit inter-zone routing
- **Internet access control**: Per-zone internet (WAN) access control
- **Declarative routing**: Easy-to-configure inter-zone routing rules

## Network Architecture

```
                    Internet
                       │
                      WAN
                       │
                 ┌─────┴─────┐
                 │  Router   │
                 │ (br-lan)  │
                 └─────┬─────┘
                       │
        ┌──────────────┼──────────────┬──────────────┐
        │              │              │              │
   VLAN Native    VLAN 10        VLAN 20        VLAN 30
   (untagged)      (WiFi)         (IoT)         (Guest)
        │              │              │              │
   192.169.1.x   192.169.10.x   192.169.20.x   192.169.30.x
```

## Configuration

### Basic Setup

Enable zones in your router configuration:

```nix
campground.router.zones = {
  enable = true;

  zones = {
    # Define your network zones here
  };
};
```

### Zone Definition

Each zone requires:

- `vlanId`: VLAN ID (null for native/untagged VLAN)
- `subnet`: Network subnet in CIDR notation
- `gateway`: Gateway IP for the zone
- `dhcp`: DHCP configuration
- `allowInternet`: Whether zone can access WAN
- `isolation`: Isolation level

#### Example Zone

```nix
wifi = {
  vlanId = 10;
  subnet = "192.169.10.0/24";
  gateway = "192.169.10.1";
  dhcp = {
    enable = true;
    rangeStart = "192.169.10.50";
    rangeEnd = "192.169.10.200";
    leaseTime = "12h";
  };
  allowInternet = true;
  isolation = "partial";
  description = "WiFi network for wireless devices";
};
```

### Isolation Levels

- **`full`**: No communication with other zones (except via interZoneRoutes)
- **`partial`**: Can communicate with LAN zone only
- **`none`**: Can communicate with all zones

### Inter-Zone Routing

Define explicit routes between zones with granular port/protocol restrictions:

```nix
interZoneRoutes = [
  # Allow unrestricted traffic (all protocols/ports)
  {
    from = "wifi";
    to = ["lan"];
    description = "WiFi can access LAN resources";
  }

  # Restrict to specific protocol and ports
  {
    from = "iot";
    to = ["lan"];
    protocol = "tcp";
    ports = [8123];  # Home Assistant only
    description = "IoT devices can access Home Assistant";
  }

  # Restrict to specific destination IPs
  {
    from = "guest";
    to = ["lan"];
    protocol = "tcp";
    ports = [9100 631];
    destinationIPs = ["192.169.1.50"];  # Printer IP
    description = "Guest can access printer only";
  }

  # Allow ICMP (ping)
  {
    from = "wifi";
    to = ["lan"];
    protocol = "icmp";
    description = "WiFi can ping LAN";
  }

  # Allow multiple ports
  {
    from = "wifi";
    to = ["lan"];
    protocol = "tcp";
    ports = [22 139 445 3389];  # SSH, SMB, RDP
    description = "WiFi to LAN services";
  }

  # Allow port ranges
  {
    from = "wifi";
    to = ["lan"];
    protocol = "tcp";
    portRanges = [{start = 8000; end = 8999;}];
    description = "WiFi to LAN development servers";
  }
];
```

#### Route Options

- **`from`**: Source zone name (required)
- **`to`**: List of destination zone names (required)
- **`protocol`**: `"tcp"`, `"udp"`, `"icmp"`, `"all"`, or `null` (default: null = all)
- **`ports`**: List of destination ports (requires protocol)
- **`portRanges`**: List of port ranges `{start, end}` (requires protocol)
- **`destinationIPs`**: List of specific IPs within destination zone (default: entire zone)
- **`description`**: Human-readable description

## Complete Example

```nix
campground.router.zones = {
  enable = true;

  zones = {
    # LAN - Native/untagged VLAN
    lan = {
      vlanId = null;
      subnet = "192.169.1.0/24";
      gateway = "192.169.1.1";
      dhcp = {
        enable = true;
        rangeStart = "192.169.1.50";
        rangeEnd = "192.169.1.200";
      };
      allowInternet = true;
      isolation = "none";
      description = "Main LAN for trusted devices";
    };

    # WiFi - VLAN 10
    wifi = {
      vlanId = 10;
      subnet = "192.169.10.0/24";
      gateway = "192.169.10.1";
      dhcp = {
        enable = true;
        rangeStart = "192.169.10.50";
        rangeEnd = "192.169.10.200";
      };
      allowInternet = true;
      isolation = "partial";  # Can access LAN only
      description = "WiFi network";
    };

    # IoT - VLAN 20
    iot = {
      vlanId = 20;
      subnet = "192.169.20.0/24";
      gateway = "192.169.20.1";
      dhcp = {
        enable = true;
        rangeStart = "192.169.20.50";
        rangeEnd = "192.169.20.200";
      };
      allowInternet = true;
      isolation = "full";  # Fully isolated
      description = "IoT devices";
    };

    # Guest - VLAN 30
    guest = {
      vlanId = 30;
      subnet = "192.169.30.0/24";
      gateway = "192.169.30.1";
      dhcp = {
        enable = true;
        rangeStart = "192.169.30.50";
        rangeEnd = "192.169.30.200";
      };
      allowInternet = true;
      isolation = "full";  # Fully isolated
      description = "Guest network";
    };
  };

  # Granular inter-zone routing with port/protocol restrictions
  interZoneRoutes = [
    # IoT can reach Home Assistant only (TCP port 8123)
    {
      from = "iot";
      to = ["lan"];
      protocol = "tcp";
      ports = [8123];
      destinationIPs = ["192.169.1.100"];  # Home Assistant IP
      description = "IoT to Home Assistant only";
    }

    # IoT can reach DNS/NTP for time sync
    {
      from = "iot";
      to = ["lan"];
      protocol = "udp";
      ports = [53 123];
      description = "IoT to DNS/NTP";
    }

    # WiFi can access file shares and SSH
    {
      from = "wifi";
      to = ["lan"];
      protocol = "tcp";
      ports = [22 139 445];  # SSH, SMB
      description = "WiFi to LAN services";
    }

    # Guest can print only
    {
      from = "guest";
      to = ["lan"];
      protocol = "tcp";
      ports = [9100 631];  # IPP, HP JetDirect
      destinationIPs = ["192.169.1.50"];  # Printer
      description = "Guest printing";
    }

    # LAN has full admin access to all zones
    {
      from = "lan";
      to = ["iot" "wifi" "guest"];
      description = "LAN admin access";
    }
  ];
};
```

## Network Switch Configuration

Your network switch must support VLANs and be configured accordingly:

### VLAN Configuration on Switch

1. **Create VLANs**:
   - VLAN 1 (Native): LAN (untagged)
   - VLAN 10: WiFi
   - VLAN 20: IoT
   - VLAN 30: Guest

2. **Trunk Port** (to Blue Ridge):
   - Port connected to enp2s0, enp3s0, or enp4s0
   - Tagged with VLANs 10, 20, 30
   - Native VLAN 1 (untagged)

3. **Access Ports**:
   - WiFi AP: VLAN 10 (untagged)
   - IoT switch: VLAN 20 (untagged)
   - Guest port: VLAN 30 (untagged)

### Example Switch Port Configuration

```
Port 1 (to Blue Ridge enp2s0): Trunk
  - Native VLAN: 1
  - Tagged VLANs: 10, 20, 30

Port 2 (WiFi AP): Access
  - VLAN 10 (untagged)

Port 3 (IoT Switch): Access
  - VLAN 20 (untagged)

Port 4 (Guest Ethernet): Access
  - VLAN 30 (untagged)

Port 5-24 (LAN): Access
  - VLAN 1 (untagged)
```

## WiFi Access Point Configuration

If using a UniFi, TP-Link, or other managed WiFi AP:

1. Create SSIDs for each network:
   - `MyNetwork` → VLAN 1 (LAN)
   - `MyNetwork-5G` → VLAN 10 (WiFi)
   - `MyNetwork-IoT` → VLAN 20 (IoT)
   - `Guest` → VLAN 30 (Guest)

2. Configure AP trunk port to carry all VLANs

3. Each SSID broadcasts on its assigned VLAN

## Management and Monitoring

### View Zone Status

```bash
router-zones
```

Output:
```
=== Network Zones ===

Zone: lan
  Interface: br-lan
  VLAN: native/untagged
  Subnet: 192.169.1.0/24
  Gateway: 192.169.1.1
  Internet: allowed
  Isolation: none
  Description: Main LAN network for trusted devices and VMs

Zone: wifi
  Interface: br-lan.10
  VLAN: 10
  Subnet: 192.169.10.0/24
  Gateway: 192.169.10.1
  Internet: allowed
  Isolation: partial
  Description: WiFi network for wireless devices

Zone: iot
  Interface: br-lan.20
  VLAN: 20
  Subnet: 192.169.20.0/24
  Gateway: 192.169.20.1
  Internet: allowed
  Isolation: full
  Description: IoT network for smart home devices

Zone: guest
  Interface: br-lan.30
  VLAN: 30
  Subnet: 192.169.30.0/24
  Gateway: 192.169.30.1
  Internet: allowed
  Isolation: full
  Description: Guest network for visitors

=== Inter-Zone Routes ===
iot -> lan [tcp] ports: 8123 -> 192.169.1.100 (IoT to Home Assistant only)
iot -> lan [udp] ports: 53,123 (IoT to DNS/NTP)
wifi -> lan [tcp] ports: 22,139,445 (WiFi to LAN services)
guest -> lan [tcp] ports: 631,9100 -> 192.169.1.50 (Guest printing only)
lan -> iot, wifi, guest (LAN admin access)
```

### View VLAN Interfaces

```bash
ip link show | grep br-lan
```

### View Zone Firewall Rules

```bash
nft list table inet zones
```

Example output:
```
table inet zones {
  set lan_nets {
    type ipv4_addr
    flags interval
    elements = { 192.169.1.0/24 }
  }

  set wifi_nets {
    type ipv4_addr
    flags interval
    elements = { 192.169.10.0/24 }
  }

  chain forward {
    type filter hook forward priority 1; policy drop;

    ct state { established, related } accept

    # Zone -> WAN
    iifname "br-lan" oifname "enp1s0" accept
    iifname "br-lan.10" oifname "enp1s0" accept

    # Inter-zone routing
    # IoT to Home Assistant only
    iifname "br-lan.20" oifname "br-lan" ip daddr 192.169.1.100 meta l4proto tcp th dport 8123 accept
    # WiFi to LAN services
    iifname "br-lan.10" oifname "br-lan" meta l4proto tcp th dport { 22, 139, 445 } accept
  }
}
```

### Test Inter-Zone Connectivity

From a device in the WiFi zone:
```bash
ping 192.169.1.1    # Should work (gateway)
ping 192.169.1.10   # Should work if interZoneRoute allows wifi->lan
ping 192.169.20.1   # Should fail (no route from wifi->iot)
```

## Common Use Cases

### 1. Home Network with IoT Isolation

```nix
zones = {
  lan.isolation = "none";      # Full access
  wifi.isolation = "partial";  # Can access LAN
  iot.isolation = "full";      # Isolated
  guest.isolation = "full";    # Isolated
};

interZoneRoutes = [
  {
    from = "iot";
    to = ["lan"];  # IoT can reach Home Assistant on LAN
    description = "IoT to Home Assistant";
  }
];
```

### 2. Work-from-Home Setup

```nix
zones = {
  lan.isolation = "none";      # Full access
  work.isolation = "full";     # Isolated work network
  wifi.isolation = "partial";  # Personal WiFi
  guest.isolation = "full";    # Guest network
};

interZoneRoutes = [
  {
    from = "work";
    to = ["lan"];  # Work devices can access network printer
    description = "Work to LAN printer";
  }
];
```

### 3. Full Isolation (Maximum Security)

```nix
zones = {
  lan.isolation = "full";
  wifi.isolation = "full";
  iot.isolation = "full";
  guest.isolation = "full";
};

# All zones isolated from each other
# Only internet access allowed (if allowInternet = true)
```

## Advanced Configuration

### Custom DNS Forwarders per Zone

```nix
guest = {
  # ... other config ...
  dns = {
    enable = true;
    customForwarders = ["1.1.1.3" "1.0.0.3"];  # Cloudflare malware blocking
  };
};
```

### Extra Firewall Rules

```nix
extraFirewallRules = ''
  # Allow IoT devices to reach specific LAN IP only
  iifname "br-lan.20" oifname "br-lan" ip daddr 192.169.1.100 accept

  # Block specific port across all zones
  tcp dport 445 drop  # Block SMB
'';
```

## Troubleshooting

### VLANs Not Working

1. Check switch configuration (trunk/access ports)
2. Verify VLAN interface creation: `ip link show`
3. Check DHCP is working: `journalctl -u dnsmasq -f`

### No Internet Access from Zone

1. Verify `allowInternet = true` for the zone
2. Check NAT is working: `nft list table ip nat`
3. Test DNS: `ping 1.1.1.1` (should work if internet allowed)

### Inter-Zone Routing Not Working

1. Verify `interZoneRoutes` configuration
2. Check firewall rules: `nft list table inet zones`
3. Test from source zone: `ping <destination-zone-ip>`

### Devices Not Getting DHCP

1. Check dnsmasq is listening: `netstat -ulnp | grep :67`
2. View DHCP logs: `journalctl -u dnsmasq -f`
3. Verify switch VLAN configuration

## Migration from Single-Network Setup

If migrating from a single LAN network:

1. Keep existing LAN configuration as-is (native VLAN)
2. Add new zones incrementally
3. Test each zone before enabling isolation
4. Configure switch VLANs one at a time

Your existing devices on the LAN will continue to work without changes.

## Security Best Practices

### Zone Isolation

1. **Guest Network**: Always use `isolation = "full"` and `allowInternet = true`
2. **IoT Devices**: Use `isolation = "full"` and only allow specific routes to LAN
3. **WiFi**: Use `isolation = "partial"` or explicit routes to LAN
4. **LAN**: Can use `isolation = "none"` for trusted devices
5. **Change default subnets**: Use unique subnets to avoid conflicts

### Granular Routing (Principle of Least Privilege)

**Always use the most restrictive routing possible:**

❌ **Bad** - Too permissive:
```nix
{
  from = "iot";
  to = ["lan"];
  description = "IoT to LAN";  # Allows ALL traffic
}
```

✅ **Good** - Specific ports only:
```nix
{
  from = "iot";
  to = ["lan"];
  protocol = "tcp";
  ports = [8123];  # Only Home Assistant
  destinationIPs = ["192.169.1.100"];
  description = "IoT to Home Assistant";
}
```

### Common Secure Patterns

**IoT Network** (maximum security):
```nix
# IoT is fully isolated
iot.isolation = "full";

# IoT can only reach specific services
interZoneRoutes = [
  {
    from = "iot";
    to = ["lan"];
    protocol = "tcp";
    ports = [8123];  # Home Assistant
    destinationIPs = ["192.169.1.100"];
    description = "IoT control";
  }
  {
    from = "iot";
    to = ["lan"];
    protocol = "udp";
    ports = [53 123];  # DNS, NTP
    description = "IoT infrastructure";
  }
];
```

**Guest Network** (no LAN access):
```nix
# Guest is fully isolated, internet only
guest = {
  isolation = "full";
  allowInternet = true;
};

# Optional: Guest can print
interZoneRoutes = [
  {
    from = "guest";
    to = ["lan"];
    protocol = "tcp";
    ports = [631 9100];
    destinationIPs = ["192.169.1.50"];
    description = "Guest printing only";
  }
];
```

**WiFi Network** (selective LAN access):
```nix
# WiFi can access LAN services
wifi.isolation = "partial";  # or "full" with explicit routes

interZoneRoutes = [
  {
    from = "wifi";
    to = ["lan"];
    protocol = "tcp";
    ports = [22 139 445 3389];  # SSH, SMB, RDP
    description = "WiFi to LAN services";
  }
  {
    from = "wifi";
    to = ["lan"];
    protocol = "icmp";
    description = "WiFi ping LAN";
  }
];
```

### Port Reference

Common ports to consider:

**File Sharing:**
- 139, 445 (SMB/CIFS)
- 2049 (NFS)
- 548 (AFP)

**Remote Access:**
- 22 (SSH)
- 3389 (RDP)
- 5900 (VNC)

**Home Automation:**
- 8123 (Home Assistant)
- 1883, 8883 (MQTT)
- 6053 (HomeKit)

**Media:**
- 32400 (Plex)
- 8096 (Jellyfin)
- 8200 (Emby)

**Printing:**
- 631 (IPP)
- 9100 (HP JetDirect)

**Infrastructure:**
- 53 (DNS)
- 123 (NTP)
- 80, 443 (HTTP/HTTPS)

## References

- nftables: https://wiki.nftables.org/
- systemd-networkd VLANs: https://www.freedesktop.org/software/systemd/man/systemd.netdev.html
- dnsmasq: https://thekelleys.org.uk/dnsmasq/doc.html
