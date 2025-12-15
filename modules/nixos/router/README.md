# Router Modules

Custom NixOS modules for easy router configuration with security hardening.

## Overview

These modules provide a simplified, declarative way to configure a NixOS system as a home router with enterprise-grade security features. They're designed to be equivalent to OpenWRT baseline functionality but with NixOS benefits like declarative configuration, atomic updates, and easy rollbacks.

## Module Structure

```
modules/nixos/router/
├── core/          # Core router functionality
├── dhcp/          # DHCP server with static leases
├── security/      # Security hardening
└── README.md      # This file
```

### `core/` - Core Router Configuration

The main router module that handles:
- WAN/LAN interface configuration
- Network bridging for multiple LAN ports
- IP forwarding and routing
- NAT/Masquerading
- DNS resolver (Unbound with DNSSEC)
- Basic firewall with nftables

#### Usage Example

```nix
campground.router = {
  enable = true;

  wan = {
    interface = "enp1s0";
    dhcp = true;
    # staticIP = "203.0.113.10/24"; # For static WAN IP
  };

  lan = {
    interfaces = ["enp2s0" "enp3s0" "enp4s0"];
    subnet = "192.168.1.0/24";
    gateway = "192.168.1.1";
  };

  enableIPv6 = false;

  dns = {
    forwarders = ["1.1.1.1" "1.0.0.1"];
    enableDNSSEC = true;
  };

  firewall = {
    allowPing = false;
    extraRules = ''
      # Custom nftables rules here
    '';
  };
};
```

### `dhcp/` - DHCP Server with Static Leases

Provides DHCP server functionality using Kea (modern, actively maintained DHCP server).

Key features:
- Easy static lease management
- Declarative configuration
- Built-in lease viewing tools
- Persistent lease database

#### Usage Example

```nix
campground.router.dhcp = {
  enable = true;
  poolStart = "192.168.1.100";
  poolEnd = "192.168.1.250";
  leaseTime = 86400; # 24 hours

  staticLeases = [
    {
      hostname = "desktop";
      mac = "00:11:22:33:44:55";
      ip = "192.168.1.10";
      description = "Main desktop computer";
    }
    {
      hostname = "nas";
      mac = "AA:BB:CC:DD:EE:FF";
      ip = "192.168.1.20";
      description = "Network storage";
    }
  ];
};
```

#### Static Lease Type

Each static lease has the following fields:

```nix
{
  hostname = "device-name";      # Hostname for the device
  mac = "00:11:22:33:44:55";    # MAC address
  ip = "192.168.1.100";         # Static IP to assign
  description = "Description";   # Optional description
}
```

#### Provided Tools

- `show-dhcp-leases` - View current DHCP leases and configured static leases
- `show-router-config` - Display router configuration summary

### `security/` - Security Hardening

Comprehensive security hardening module for routers.

Features:
- SSH configuration (LAN-only by default)
- fail2ban integration
- Kernel hardening
- Minimal package set
- Automatic security updates
- Security audit logging
- Service restriction

#### Usage Example

```nix
campground.router.security = {
  enable = true;

  enableSSH = true;
  sshPort = 22;

  enableWebUI = false; # Not implemented yet

  fail2ban = {
    enable = true;
    maxRetry = 3;
    banTime = 3600; # 1 hour
  };

  allowedServices = [
    {
      port = 8080;
      protocol = "tcp";
      interface = "br-lan";
    }
  ];
};
```

#### Security Hardening Applied

**Network Security:**
- rp_filter enabled (prevents IP spoofing)
- No IP redirects accepted
- No source routing
- SYN cookies enabled
- Martian packet logging
- SYN flood protection
- Time-wait assassination protection

**System Security:**
- Kernel image protection
- dmesg restricted
- Kernel pointer restriction
- Unprivileged BPF disabled
- BPF JIT hardening
- Unprivileged user namespaces disabled
- Coredumps disabled
- Temporary files cleaned on boot

**SSH Security:**
- Password authentication disabled
- Root login disabled
- Modern ciphers only (ChaCha20, AES-GCM)
- Modern key exchange (Curve25519)
- Modern MACs (SHA2)
- LAN-only access by default

**Service Minimization:**
- No Avahi
- No printing
- No audio
- No GUI
- No X server
- Minimal package set

#### Provided Tools

- `router-security-check` - Check security status, active connections, SSH attempts, and fail2ban status

## Architecture

### Network Topology

```
Internet
   ↓
WAN Interface (enp1s0)
   ↓
[NAT/Firewall]
   ↓
LAN Bridge (br-lan)
   ├── enp2s0
   ├── enp3s0
   └── enp4s0
       ↓
   LAN Devices
```

### Service Dependencies

```
systemd-networkd → Creates bridge and assigns interfaces
        ↓
   kea-dhcp4 → Provides DHCP on br-lan
        ↓
    unbound → DNS resolver with DNSSEC
        ↓
   nftables → Firewall and NAT
```

## Port Forwarding

The router module provides a clean, declarative way to configure port forwarding:

```nix
campground.router.portForwards = [
  {
    port = 443;
    destination = "192.168.1.100";
    protocol = "tcp";
    description = "HTTPS to web server";
  }
  {
    port = 25565;
    destination = "192.168.1.50";
    destinationPort = 25565;  # Optional: forward to different port
    protocol = "both";         # tcp, udp, or both
    description = "Minecraft server";
  }
  {
    port = 80;
    destination = "192.168.1.100";
    # protocol defaults to "tcp"
    # destinationPort defaults to same as port
  }
];
```

### Port Forward Options

Each port forward has the following options:

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `port` | int | Yes | External port on WAN to forward |
| `destination` | string | Yes | Internal IP to forward to |
| `destinationPort` | int? | No | Internal port (defaults to `port`) |
| `protocol` | enum | No | "tcp", "udp", or "both" (default: "tcp") |
| `description` | string | No | Human-readable description |

## Module Options Reference

### `campground.router.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable router configuration |
| `wan.interface` | string | - | WAN interface name |
| `wan.dhcp` | bool | true | Use DHCP on WAN |
| `wan.staticIP` | string? | null | Static WAN IP |
| `lan.interfaces` | list | - | LAN interfaces to bridge |
| `lan.subnet` | string | - | LAN subnet (CIDR) |
| `lan.gateway` | string | - | Router IP on LAN |
| `portForwards` | list | [] | Declarative port forwards |
| `enableIPv6` | bool | false | Enable IPv6 routing |
| `dns.forwarders` | list | [1.1.1.1...] | DNS forwarders |
| `dns.enableDNSSEC` | bool | true | Enable DNSSEC |
| `firewall.allowPing` | bool | false | Allow WAN ping |
| `firewall.extraRules` | string | "" | Extra nftables rules |

### `campground.router.dhcp.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | true | Enable DHCP server |
| `poolStart` | string | - | DHCP pool start IP |
| `poolEnd` | string | - | DHCP pool end IP |
| `leaseTime` | int | 86400 | Lease time (seconds) |
| `staticLeases` | list | [] | Static DHCP leases |
| `extraOptions` | string | "" | Extra Kea config |

### `campground.router.security.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | true | Enable security hardening |
| `enableSSH` | bool | true | Enable SSH server |
| `sshPort` | int | 22 | SSH port |
| `enableWebUI` | bool | false | Enable web UI (N/A) |
| `allowedServices` | list | [] | Additional services |
| `fail2ban.enable` | bool | true | Enable fail2ban |
| `fail2ban.maxRetry` | int | 3 | Max login attempts |
| `fail2ban.banTime` | int | 3600 | Ban duration (sec) |

## Extending the Modules

### Adding Custom Firewall Rules

For most port forwarding needs, use the declarative `portForwards` option (see Port Forwarding section above). For advanced custom rules:

```nix
campground.router.firewall.extraRules = ''
  table inet filter {
    chain input {
      # Allow custom service on router itself
      tcp dport 8080 accept
    }
  }
'';
```

### Adding VLANs

To add VLAN support, you can extend the configuration:

```nix
systemd.network.netdevs."20-vlan10" = {
  netdevConfig = {
    Kind = "vlan";
    Name = "vlan10";
  };
  vlanConfig.Id = 10;
};

systemd.network.networks."30-vlan10" = {
  matchConfig.Name = "vlan10";
  networkConfig = {
    Address = "192.168.10.1/24";
  };
  vlanConfig.Id = 10;
};
```

### Adding WireGuard VPN

```nix
networking.wireguard.interfaces.wg0 = {
  ips = ["10.100.0.1/24"];
  listenPort = 51820;

  privateKeyFile = "/etc/wireguard/private.key";

  peers = [
    {
      publicKey = "peer-public-key";
      allowedIPs = ["10.100.0.2/32"];
    }
  ];
};

# Allow WireGuard through firewall
campground.router.firewall.extraRules = ''
  table inet filter {
    chain input {
      udp dport 51820 accept
    }
  }
'';
```

## Best Practices

1. **Always use version control** - Keep your router config in Git
2. **Test in a VM first** - Use `nixos-rebuild build-vm` to test changes
3. **Keep static leases organized** - Use descriptive hostnames and descriptions
4. **Use declarative port forwards** - Use `portForwards` option with descriptions
5. **Regular backups** - Backup `/etc/nixos` and any secret files
6. **Monitor logs** - Check `journalctl -f` periodically
7. **Update regularly** - Keep the system updated for security

## Troubleshooting

### Module Not Found

Ensure the module is in `modules/nixos/router/` and Snowfall is configured correctly.

### Network Interfaces Not Found

Run `ip link` to find actual interface names and update configuration.

### DHCP Not Working

```bash
# Check Kea status
systemctl status kea-dhcp4-server

# View leases
cat /var/lib/kea/dhcp4.leases | jq

# Check logs
journalctl -u kea-dhcp4-server -f
```

### DNS Not Resolving

```bash
# Check Unbound status
systemctl status unbound

# Test DNS
dig @127.0.0.1 google.com

# Check logs
journalctl -u unbound -f
```

### Firewall Blocking Traffic

```bash
# View current rules
nft list ruleset

# Add logging to debug
campground.router.firewall.extraRules = ''
  table inet filter {
    chain input {
      log prefix "INPUT: "
    }
    chain forward {
      log prefix "FORWARD: "
    }
  }
'';
```

## Contributing

To add features to these modules:

1. Create a new directory with a `default.nix` file (e.g., `modules/nixos/router/vlan/default.nix`)
2. Follow the existing module pattern (see `core/`, `dhcp/`, or `security/`)
3. Use the namespace (`campground.router.<module-name>`)
4. Document options with examples
5. Provide helper scripts where useful
6. Update this README

## License

These modules are part of the Campground configuration and follow the same license.
