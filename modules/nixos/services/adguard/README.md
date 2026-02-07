# AdGuard Home Module

A comprehensive NixOS module for AdGuard Home - a network-wide ad blocker and privacy protection tool.

## Features

- **DNS-based ad blocking** - Block ads, trackers, and malicious domains network-wide
- **DNS-over-HTTPS/TLS/QUIC** - Encrypted DNS with privacy protection
- **DNSSEC validation** - Cryptographic authentication of DNS responses
- **Parental controls** - Block adult content and enforce safe search
- **DHCP server** - Optional DHCP server functionality
- **Query logging** - Detailed DNS query logs and statistics
- **Customizable filtering** - Add custom blocklists and allowlists

## Basic Configuration

```nix
campground.services.adguard = {
  enable = true;
  host = "0.0.0.0";
  port = 3000;
  openFirewall = true;

  dns = {
    port = 53;
    upstreamDns = [
      "https://dns.cloudflare.com/dns-query"
      "https://dns.google/dns-query"
    ];
    enableDNSSEC = true;
  };
};
```

## DNS Configuration

### Basic DNS Settings

```nix
campground.services.adguard.dns = {
  port = 53;
  bindHosts = [ "0.0.0.0" ];

  # Upstream DNS servers (supports DoH, DoT, DoQ)
  upstreamDns = [
    "https://dns.cloudflare.com/dns-query"  # Cloudflare DoH
    "tls://dns.google"                       # Google DoT
    "quic://dns.adguard.com"                # AdGuard DoQ
    "1.1.1.1"                               # Cloudflare plain DNS
  ];

  # Bootstrap DNS for resolving DoH/DoT hostnames
  bootstrapDns = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  enableDNSSEC = true;
};
```

### DNS Cache Configuration

```nix
campground.services.adguard.dns = {
  cacheSize = 4194304;        # 4MB cache
  cacheTtlMin = 300;          # Minimum 5 minutes
  cacheTtlMax = 86400;        # Maximum 24 hours
};
```

### Blocking Modes

```nix
campground.services.adguard.dns = {
  # How to respond to blocked domains:
  # - "default": AdGuard's default blocked page
  # - "nxdomain": Return NXDOMAIN
  # - "null_ip": Return 0.0.0.0/::
  # - "custom_ip": Return custom IP
  blockingMode = "nxdomain";

  # If using custom_ip mode:
  blockingIpv4 = "192.168.1.1";
  blockingIpv6 = "::1";
};
```

### DDoS Protection

```nix
campground.services.adguard.dns = {
  ratelimit = 20;  # Max 20 requests/second per client
};
```

## Filtering Configuration

### Default Configuration

By default, AdGuard DNS filter is enabled:

```nix
campground.services.adguard.filtering = {
  enable = true;
  updateInterval = 24;  # Update filters every 24 hours

  filters = [
    {
      enabled = true;
      name = "AdGuard DNS filter";
      url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
    }
  ];
};
```

### Popular Filter Lists

```nix
campground.services.adguard.filtering.filters = [
  {
    enabled = true;
    name = "AdGuard DNS filter";
    url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
  }
  {
    enabled = true;
    name = "AdAway Default Blocklist";
    url = "https://adaway.org/hosts.txt";
  }
  {
    enabled = true;
    name = "Steven Black's Unified hosts";
    url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
  }
  {
    enabled = true;
    name = "EasyList";
    url = "https://easylist.to/easylist/easylist.txt";
  }
  {
    enabled = true;
    name = "EasyPrivacy";
    url = "https://easylist.to/easylist/easyprivacy.txt";
  }
];
```

## Privacy Features

### Safe Browsing & Parental Controls

```nix
campground.services.adguard = {
  safeBrowsing.enable = true;     # Block malicious domains
  parentalControl.enable = true;  # Block adult content
  safeSearch.enable = true;       # Enforce safe search
};
```

### Query Logging

```nix
campground.services.adguard.queryLog = {
  enabled = true;
  interval = "2160h";           # 90 days
  anonymizeClientIp = false;    # Set to true for privacy
};
```

### Statistics

```nix
campground.services.adguard.statistics = {
  enabled = true;
  interval = "24h";  # Keep stats for 24 hours
};
```

## DNS-over-HTTPS/TLS/QUIC (Encrypted DNS)

### Enable Encrypted DNS

```nix
campground.services.adguard.tls = {
  enable = true;
  port = 853;              # DoT port
  portHttps = 443;         # DoH port
  portQuic = 853;          # DoQ port

  certificatePath = "/var/lib/acme/dns.example.com/cert.pem";
  privateKeyPath = "/var/lib/acme/dns.example.com/key.pem";
  serverName = "dns.example.com";
};
```

### Client Configuration

After enabling TLS, configure clients to use encrypted DNS:

**DNS-over-HTTPS:**
```
https://dns.example.com/dns-query
```

**DNS-over-TLS:**
```
dns.example.com:853
```

**DNS-over-QUIC:**
```
quic://dns.example.com:853
```

## DHCP Server

AdGuard Home can replace your router's DHCP server:

```nix
campground.services.adguard.dhcp = {
  enable = true;
  interface = "enp2s0";
  gatewayIp = "192.168.1.1";
  subnetMask = "255.255.255.0";
  rangeStart = "192.168.1.100";
  rangeEnd = "192.168.1.200";
  leaseDuration = 86400;  # 24 hours
};
```

**Important:** Disable your router's DHCP server before enabling this!

## Integration with Router Module

If you're using the campground router module, you can replace dnsmasq with AdGuard Home:

```nix
# Disable router's built-in DNS
campground.router.dns.enable = false;

# Enable AdGuard Home
campground.services.adguard = {
  enable = true;
  openFirewall = true;

  dns = {
    port = 53;
    bindHosts = [ "192.168.1.1" ];  # Router IP
    upstreamDns = [
      "https://dns.cloudflare.com/dns-query"
      "https://dns.google/dns-query"
    ];
    enableDNSSEC = true;
  };

  # Optional: Use AdGuard's DHCP instead of dnsmasq
  dhcp = {
    enable = true;
    interface = "br-lan";
    gatewayIp = "192.168.1.1";
    subnetMask = "255.255.255.0";
    rangeStart = "192.168.1.50";
    rangeEnd = "192.168.1.200";
  };
};
```

## Example: Complete Setup

```nix
campground.services.adguard = {
  enable = true;
  host = "0.0.0.0";
  port = 3000;
  openFirewall = true;
  mutableSettings = true;  # Allow web UI changes

  dns = {
    port = 53;
    bindHosts = [ "0.0.0.0" ];

    upstreamDns = [
      "https://dns.cloudflare.com/dns-query"
      "https://dns.google/dns-query"
      "1.1.1.1"
      "8.8.8.8"
    ];

    bootstrapDns = [ "1.1.1.1" "8.8.8.8" ];

    enableDNSSEC = true;
    blockingMode = "nxdomain";
    ratelimit = 30;
    cacheSize = 8388608;  # 8MB
  };

  filtering = {
    enable = true;
    updateInterval = 24;

    filters = [
      {
        enabled = true;
        name = "AdGuard DNS filter";
        url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
      }
      {
        enabled = true;
        name = "AdAway Default Blocklist";
        url = "https://adaway.org/hosts.txt";
      }
    ];
  };

  safeBrowsing.enable = true;

  queryLog = {
    enabled = true;
    interval = "2160h";  # 90 days
    anonymizeClientIp = false;
  };

  statistics = {
    enabled = true;
    interval = "24h";
  };
};
```

## Module Options Reference

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable AdGuard Home |
| `package` | package | pkgs.adguardhome | Package to use |
| `host` | string | "0.0.0.0" | Web interface host |
| `port` | int | 3000 | Web interface port |
| `openFirewall` | bool | false | Open firewall ports |
| `mutableSettings` | bool | true | Allow web UI changes |

### DNS Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `dns.port` | int | 53 | DNS server port |
| `dns.bindHosts` | list | ["0.0.0.0"] | Bind addresses |
| `dns.upstreamDns` | list | [...] | Upstream DNS servers |
| `dns.bootstrapDns` | list | [...] | Bootstrap DNS servers |
| `dns.enableDNSSEC` | bool | true | Enable DNSSEC |
| `dns.blockingMode` | enum | "default" | Blocking mode |
| `dns.ratelimit` | int | 20 | Requests/second limit |
| `dns.cacheSize` | int | 4194304 | Cache size in bytes |

### Filtering Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `filtering.enable` | bool | true | Enable filtering |
| `filtering.updateInterval` | int | 24 | Update interval (hours) |
| `filtering.filters` | list | [...] | Filter lists |

### Privacy Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `safeBrowsing.enable` | bool | false | Block malicious sites |
| `parentalControl.enable` | bool | false | Block adult content |
| `safeSearch.enable` | bool | false | Enforce safe search |
| `queryLog.enabled` | bool | true | Enable query logging |
| `queryLog.anonymizeClientIp` | bool | false | Anonymize IPs |

## Accessing the Web Interface

After enabling AdGuard Home, access the web interface at:

```
http://<host-ip>:3000
```

Default credentials are set during first-time setup.

## Testing

Test DNS resolution:

```bash
# Test DNS blocking
dig @<adguard-ip> ads.example.com

# Test DNSSEC
dig @<adguard-ip> dnssec-deployment.org

# Test DoH (if enabled)
curl -H 'accept: application/dns-json' \
  'https://dns.example.com/dns-query?name=example.com'
```

## Troubleshooting

### Check service status

```bash
systemctl status adguardhome
journalctl -u adguardhome -f
```

### Port conflicts

If port 53 is already in use:

```bash
# Find what's using port 53
sudo lsof -i :53

# Disable systemd-resolved if needed
services.resolved.enable = false;
```

### DNS not resolving

Check firewall:

```bash
# Ensure port 53 is open
sudo nft list ruleset | grep 53
```

## Performance Tuning

For high-traffic networks:

```nix
campground.services.adguard.dns = {
  cacheSize = 16777216;              # 16MB cache
  ratelimit = 0;                      # Disable rate limiting
  enableParallelUpstreamQueries = true;  # Query all upstreams in parallel
};
```

## Security Considerations

1. **Change default web UI port** if exposed to internet
2. **Use strong passwords** for web interface
3. **Enable DNSSEC** for DNS authentication
4. **Use encrypted DNS** (DoH/DoT/DoQ) for upstream servers
5. **Enable safe browsing** for malware protection
6. **Review query logs** regularly for suspicious activity

## Related Modules

- `campground.router` - Router with DNS support
- `campground.services.vault-agent` - Secret management (for TLS certs)
- `campground.suites.lan-hosting` - LAN service hosting with Traefik

## References

- [AdGuard Home Documentation](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [NixOS AdGuard Home Options](https://search.nixos.org/options?query=services.adguardhome)
- [DNS-over-HTTPS/TLS/QUIC Setup](https://github.com/AdguardTeam/AdGuardHome/wiki/Encryption)
- [Filter Lists](https://github.com/AdguardTeam/AdGuardHome/wiki/Hosts-Blocklists)
