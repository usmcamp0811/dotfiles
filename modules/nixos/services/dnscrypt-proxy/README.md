# dnscrypt-proxy with ODoH Module

This NixOS module provides privacy-preserving DNS resolution using dnscrypt-proxy with Oblivious DNS over HTTPS (ODoH).

## What is ODoH?

ODoH (Oblivious DNS over HTTPS) is a protocol that separates knowledge of **who** is making a DNS query from **what** the query is:

- **Relay** sees: Your IP address + encrypted query (can't read it)
- **Target resolver** sees: Decrypted query + relay's IP (not yours)
- **Result**: No single entity can correlate your identity with your DNS queries

This provides stronger privacy than standard DoH (DNS over HTTPS), where the resolver sees both your IP and queries.

## Features

- **ODoH Support**: Routes queries through relays for metadata privacy
- **OISD Blocklist**: Integrated ad/malware blocking using the OISD big blocklist (fetched at build time)
- **DNSSEC**: Cryptographic validation of DNS responses
- **Flexible Configuration**: Customize servers, relays, and routing
- **Fallback Ready**: Works alongside other DNS solutions

## OISD Blocklist Updates

The OISD blocklist is fetched at **build time** (not as a flake input) to avoid breaking downstream consumers when the nightly blocklist updates.

### Updating the Blocklist Hash

The blocklist hash should be updated periodically (weekly or monthly recommended):

```bash
# 1. Get the new hash
nix-prefetch-url https://big.oisd.nl/domainswild

# 2. Update the sha256 in modules/nixos/services/dnscrypt-proxy/default.nix
#    Look for the oisd-blocklist definition and update:
#    - sha256 = "NEW_HASH_HERE";
#    - # Last updated: YYYY-MM-DD

# 3. Test the change
nix flake check

# 4. Commit
git add modules/nixos/services/dnscrypt-proxy/default.nix
git commit -m "chore: update OISD blocklist hash"
```

**Why not a flake input?** The blocklist updates nightly. As a flake input, every update would change `flake.lock`, breaking consumers who haven't updated yet. Fetching at build time means:
- Consumers aren't affected by blocklist updates
- You control when to update (not forced nightly)
- Flake remains stable for downstream users

## Basic Usage

### Enable with Defaults

```nix
{
  fmf.services.dnscrypt-proxy.enable = true;
}
```

This enables dnscrypt-proxy with:
- Listen on `127.0.0.1:5353` and `[::1]:5353`
- Use Cloudflare and Snowstorm ODoH servers
- Route through crypto.sx relay
- OISD blocklist enabled
- DNSSEC validation required

### Use with AdGuard Home

Point AdGuard's upstream DNS to dnscrypt-proxy:

```nix
{
  fmf.services.dnscrypt-proxy.enable = true;

  fmf.services.adguard = {
    enable = true;
    dns.upstreamDns = [
      "127.0.0.1:5353"  # dnscrypt-proxy (primary)
      "https://cloudflare-dns.com/dns-query"  # Fallback
    ];
  };
}
```

### Use as System Resolver

To use dnscrypt-proxy as your system's primary DNS:

```nix
{
  fmf.services.dnscrypt-proxy = {
    enable = true;
    listenAddresses = ["127.0.0.1:53"];  # Standard DNS port
  };

  networking.nameservers = ["127.0.0.1"];
}
```

## Configuration Options

### Server Selection

```nix
{
  fmf.services.dnscrypt-proxy = {
    enable = true;

    # Choose which ODoH servers to use
    serverNames = [
      "odoh-cloudflare"
      "odoh-snowstorm"
      "odoh-google"
    ];

    # Enable/disable server types
    odohServers = true;      # Oblivious DoH
    dnscryptServers = true;  # DNSCrypt protocol
  };
}
```

### Anonymized DNS Routing

Configure how queries are routed through relays:

```nix
{
  fmf.services.dnscrypt-proxy = {
    enable = true;

    anonymizedDns = {
      enable = true;
      skipIncompatible = true;  # Skip servers that don't support ODoH

      # Define routing: which relay to use for which server
      routes = [
        {
          server_name = "odoh-cloudflare";
          via = ["odohrelay-crypto-sx"];  # Route via crypto.sx relay
        }
        {
          server_name = "odoh-snowstorm";
          via = ["odohrelay-surf"];       # Route via SURF relay
        }
      ];
    };
  };
}
```

### Security Settings

```nix
{
  fmf.services.dnscrypt-proxy = {
    enable = true;

    # DNSSEC validation
    requireDNSSEC = true;

    # Only use servers with specific privacy properties
    requireNolog = true;      # No query logging
    requireNofilter = false;  # Allow content filtering

    # IPv6 configuration
    hasIPv6Internet = true;   # Use IPv6 servers
  };
}
```

### Custom Blocklist

Add extra domains to block beyond OISD:

```nix
{
  fmf.services.dnscrypt-proxy = {
    enable = true;

    extraBlocklist = ''
      # Block specific tracking domains
      analytics.example.com
      telemetry.example.org

      # Wildcard blocking
      *.ads.example.com
    '';
  };
}
```

### Advanced Configuration

For settings not exposed by the module:

```nix
{
  fmf.services.dnscrypt-proxy = {
    enable = true;

    extraSettings = {
      # Adjust timeouts
      timeout = 5000;  # milliseconds

      # Disable specific features
      block_unqualified = false;

      # Custom cache settings (handled by underlying service)
      cache = true;
      cache_size = 4096;
    };
  };
}
```

## Available ODoH Servers

The module pulls from the official DNSCrypt resolver lists. Common servers include:

- `odoh-cloudflare` - Cloudflare's ODoH resolver
- `odoh-snowstorm` - Snowstorm ODoH resolver
- `odoh-google` - Google's ODoH resolver

## Available Relays

Common ODoH relays:

- `odohrelay-crypto-sx` - crypto.sx relay (Netherlands)
- `odohrelay-surf` - SURF relay (Netherlands)
- `odohrelay-koki-ams` - Koki relay (Amsterdam)

## Testing

### Verify dnscrypt-proxy is Running

```bash
systemctl status dnscrypt-proxy2
```

### Test DNS Resolution

```bash
# Test dnscrypt-proxy directly
dig @127.0.0.1 -p 5353 google.com

# Test with nslookup
nslookup google.com 127.0.0.1 -port=5353
```

### Check DNS Leaks

Visit these sites from a device using your DNS:
- https://dnsleaktest.com
- https://ipleak.net

You should see your configured ODoH resolver (e.g., Cloudflare), **not your ISP**.

### Monitor Queries

```bash
# Watch dnscrypt-proxy logs
journalctl -u dnscrypt-proxy2 -f
```

## Architecture

```
┌──────────────┐
│ Your Device  │
└──────┬───────┘
       │ DNS Query
       ▼
┌──────────────────┐
│ dnscrypt-proxy   │ ← Listening on 127.0.0.1:5353
│ (localhost)      │
└──────┬───────────┘
       │ Encrypted Query + Your IP
       ▼
┌──────────────────┐
│  ODoH Relay      │ ← Sees: Your IP, can't read query
│  (e.g. crypto.sx)│
└──────┬───────────┘
       │ Encrypted Query + Relay IP
       ▼
┌──────────────────┐
│ ODoH Resolver    │ ← Sees: Query, only knows relay IP
│ (e.g. Cloudflare)│
└──────┬───────────┘
       │ DNS Response
       ▼
    (returns back through relay)
```

## Privacy Benefits

1. **Metadata Privacy**: Resolver can't build profile of your browsing
2. **Split Trust**: No single party knows both your identity and queries
3. **ISP Protection**: ISP only sees encrypted traffic to relay
4. **Subpoena Resistance**: Requests for "who queried X" only reveal relay IPs
5. **Traffic Analysis Protection**: Harder to correlate DNS with other activity

## Performance Considerations

- **Latency**: Adds 50-200ms due to relay hop (usually imperceptible)
- **Reliability**: Depends on relay availability (module includes fallbacks)
- **Bandwidth**: Minimal overhead from encryption

## Comparison with Other DNS Solutions

| Feature | Standard DNS | DoH | dnscrypt-proxy + ODoH |
|---------|-------------|-----|----------------------|
| ISP can see queries | ✅ Yes | ❌ No | ❌ No |
| Resolver sees your IP | ✅ Yes | ✅ Yes | ❌ No |
| Encrypted in transit | ❌ No | ✅ Yes | ✅ Yes |
| DNSSEC support | ⚠️ Maybe | ✅ Yes | ✅ Yes |
| Ad/malware blocking | ❌ No | ❌ No | ✅ Yes (OISD) |
| Metadata privacy | ❌ No | ❌ No | ✅ Yes |

## Troubleshooting

### dnscrypt-proxy Won't Start

Check systemd status:
```bash
systemctl status dnscrypt-proxy2
journalctl -u dnscrypt-proxy2 -n 50
```

Common issues:
- Port 5353 already in use
- Cannot fetch resolver lists (check internet connectivity)
- State directory permissions

### DNS Resolution Slow

- Check relay latency: Some relays may be geographically distant
- Try different servers/relays in configuration
- Enable parallel upstream queries in `extraSettings`

### DNS Not Working

If AdGuard can't reach dnscrypt-proxy:
```bash
# From AdGuard VM
dig @127.0.0.1 -p 5353 google.com
```

If this fails, check firewall or dnscrypt-proxy service status.

## Security Considerations

- **Trust Model**: You're trusting the relay and resolver don't collude
- **Choose Different Providers**: Use relays and resolvers from different entities
- **Update Regularly**: Keep resolver lists fresh (automatic by default)
- **Monitor Logs**: Watch for unusual failures or patterns

## References

- [ODoH RFC 9230](https://datatracker.ietf.org/doc/html/rfc9230)
- [dnscrypt-proxy Documentation](https://github.com/DNSCrypt/dnscrypt-proxy)
- [OISD Blocklist](https://oisd.nl/)
- [DNSCrypt Resolver Lists](https://github.com/DNSCrypt/dnscrypt-resolvers)

## Example: Complete Privacy-Focused Setup

```nix
{
  # Maximum privacy DNS setup
  fmf.services.dnscrypt-proxy = {
    enable = true;
    listenAddresses = ["127.0.0.1:5353"];

    # Use multiple ODoH servers for redundancy
    serverNames = [
      "odoh-cloudflare"
      "odoh-snowstorm"
    ];

    # Route through different relays for each server
    anonymizedDns = {
      enable = true;
      routes = [
        {
          server_name = "odoh-cloudflare";
          via = ["odohrelay-crypto-sx"];  # Netherlands relay
        }
        {
          server_name = "odoh-snowstorm";
          via = ["odohrelay-surf"];       # Different relay
        }
      ];
    };

    # Strict privacy requirements
    requireDNSSEC = true;
    requireNolog = true;

    # Block ads/trackers with OISD
    extraBlocklist = ''
      # Add custom tracking domains
      metrics.company.com
      analytics.company.com
    '';
  };

  # Use with AdGuard for additional filtering
  fmf.services.adguard = {
    enable = true;
    dns = {
      upstreamDns = ["127.0.0.1:5353"];
      bootstrapDns = ["1.1.1.1"];  # Only for fallback
      enableDNSSEC = true;
    };
  };
}
```
