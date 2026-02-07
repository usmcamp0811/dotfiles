# Blue Ridge Router Configuration

NixOS-based home router configuration for Intel N100 4-LAN mini PC with impermanence.

## Hardware

- **CPU**: Intel N100 (Alder Lake-N)
- **RAM**: 32GB
- **Storage**: 256GB SSD
- **Network**: 4x Intel I226-V 2.5GbE NICs

## ⚠️ IMPORTANT: Impermanence Enabled

This router uses **impermanence** - the root filesystem is ephemeral and wiped on every boot!

- **Root (/)**: tmpfs (2GB, wiped on boot)
- **Nix Store (/nix)**: persistent partition (50GB)
- **State (/persist)**: persistent partition (remaining space)

**If it's not in `/persist`, it's gone on reboot!**

See [INSTALL.md](./INSTALL.md) for detailed installation instructions.

## Network Layout

- **WAN**: enp1s0 (Port 1)
- **LAN**: enp2s0, enp3s0, enp4s0 (Ports 2-4, bridged as br-lan)
- **LAN Subnet**: 192.168.1.0/24
- **Router IP**: 192.168.1.1
- **DHCP Pool**: 192.168.1.100 - 192.168.1.250

## Features

### Core Router Functionality
- NAT/Masquerading for internet sharing
- DHCP server with static lease management (Kea)
- DNS resolver with DNSSEC (Unbound)
- Firewall with nftables (default deny, stateful)
- IPv4 routing (IPv6 can be enabled)

### Security Hardening
- Minimal attack surface (no GUI, minimal packages)
- SSH access restricted to LAN only
- fail2ban for brute-force protection
- Kernel hardening (SYN cookies, rp_filter, etc.)
- Security audit logging
- Automatic security updates (no auto-reboot)
- Modern SSH ciphers only

### Management Tools
- `show-dhcp-leases` - View current DHCP leases and static assignments
- `show-router-config` - Display router configuration summary
- `router-security-check` - Check security status and recent events

## Initial Setup

**See [INSTALL.md](./INSTALL.md) for complete installation instructions with impermanence setup.**

Quick overview:

### 1. Prepare Installation Media

```bash
# Download NixOS minimal ISO
wget https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso
dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress
```

### 2. Partition for Impermanence

```bash
# Three partitions needed:
# 1. /boot (512MB, FAT32)
# 2. /nix (50GB, ext4)
# 3. /persist (remaining, ext4)

parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart primary ext4 512MiB 50.5GiB
parted /dev/sda -- mkpart primary ext4 50.5GiB 100%

# Format with labels (MUST match hardware.nix)
mkfs.fat -F 32 -n boot /dev/sda1
mkfs.ext4 -L nix /dev/sda2
mkfs.ext4 -L persist /dev/sda3

# Mount for installation
mount -t tmpfs none /mnt
mkdir -p /mnt/{boot,nix,persist}
mount /dev/disk/by-label/boot /mnt/boot
mount /dev/disk/by-label/nix /mnt/nix
mount /dev/disk/by-label/persist /mnt/persist
mkdir -p /mnt/persist/{system,home/admin}
```

### 3. Configure SSH Key

Before deploying, add your SSH public key to `default.nix`:

```nix
openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-key-here"
];
```

### 4. Set User Password

Generate a password hash:

```bash
mkpasswd -m sha-512
```

Add it to `default.nix`:

```nix
users.users.admin = {
  hashedPassword = "$6$rounds=..."; # Your hash here
  # ...
};
```

### 5. Identify Network Interfaces

After first boot, SSH in and run:

```bash
ip link show
```

Update `default.nix` with the actual interface names if they differ from:
- WAN: enp1s0
- LAN: enp2s0, enp3s0, enp4s0

### 6. Deploy Configuration

From your main machine:

```bash
# Build the configuration
nixos-rebuild build --flake .#blue-ridge

# Deploy to router (after initial install)
nixos-rebuild switch --flake .#blue-ridge --target-host admin@192.168.1.1
```

## Managing Static DHCP Leases

Edit `default.nix` and add/modify the `staticLeases` list:

```nix
${namespace}.router.dhcp.staticLeases = [
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
```

Then rebuild and deploy:

```bash
nixos-rebuild switch --flake .#blue-ridge --target-host admin@192.168.1.1
```

To view current leases:

```bash
ssh admin@192.168.1.1 show-dhcp-leases
```

## Impermanence Management

### Check Ephemeral Status

```bash
# Verify root is tmpfs and check usage
check-ephemeral

# Show what's being persisted
show-persisted
```

### Adding New Persistent Data

If you need to persist additional directories, edit `impermanence.nix`:

```nix
environment.persistence."/persist/system" = {
  directories = [
    # ... existing ...
    "/var/lib/new-service"
  ];
};
```

### Important Reminders

- **DHCP leases** are persisted in `/var/lib/kea` (automatically configured)
- **DNS cache** and DNSSEC keys persisted in `/var/lib/unbound`
- **SSH host keys** persisted in `/etc/ssh`
- **Logs** persisted in `/var/log`
- **User home** bind-mounted from `/persist/home/admin`

**Everything else is wiped on reboot!**

## Port Forwarding

Add port forwarding rules in the `firewall.extraRules` section:

```nix
firewall.extraRules = ''
  table inet nat {
    chain prerouting {
      # Forward external port 8080 to internal server port 80
      iifname "enp1s0" tcp dport 8080 dnat to 192.168.1.100:80

      # Forward external SSH on port 2222 to internal server
      iifname "enp1s0" tcp dport 2222 dnat to 192.168.1.100:22
    }
  }

  table inet filter {
    chain forward {
      # Allow forwarded traffic to internal server
      iifname "enp1s0" oifname "br-lan" ip daddr 192.168.1.100 ct state new accept
    }
  }
'';
```

## Security Considerations

### What's Locked Down
- Default DROP policy on WAN input
- No WAN management access (SSH is LAN-only)
- Password authentication disabled
- Root login disabled
- fail2ban protection
- Kernel hardening enabled
- Minimal package set
- No GUI or unnecessary services

### Additional Hardening (Optional)

1. **Change SSH Port**: Edit `security.sshPort` in config
2. **Add fail2ban rules**: Extend fail2ban configuration for other services
3. **Enable auditd rules**: Add custom audit rules for sensitive files
4. **VPN**: Consider adding WireGuard for remote access
5. **IDS**: Consider adding Suricata for intrusion detection

## Monitoring

### View System Status

```bash
ssh admin@192.168.1.1

# System resources
htop

# Network connections
netstat -tn

# View logs
journalctl -f

# Security check
router-security-check

# DHCP leases
show-dhcp-leases

# Router config summary
show-router-config
```

### Network Performance

```bash
# Test throughput from LAN client
iperf3 -c 192.168.1.1

# Monitor interface statistics
watch -n 1 'ip -s link'

# Connection tracking
conntrack -L | wc -l
```

## Troubleshooting

### No Internet Access

1. Check WAN interface has IP:
   ```bash
   ip addr show enp1s0
   ```

2. Check routing:
   ```bash
   ip route
   ```

3. Check NAT is working:
   ```bash
   nft list table inet nat
   ```

4. Test DNS:
   ```bash
   dig @127.0.0.1 google.com
   ```

### DHCP Not Working

1. Check Kea is running:
   ```bash
   systemctl status kea-dhcp4-server
   ```

2. View DHCP logs:
   ```bash
   journalctl -u kea-dhcp4-server -f
   ```

3. Check lease file:
   ```bash
   cat /var/lib/kea/dhcp4.leases | jq
   ```

### Firewall Issues

1. View nftables rules:
   ```bash
   nft list ruleset
   ```

2. Monitor blocked packets (add logging rule):
   ```nix
   firewall.extraRules = ''
     table inet filter {
       chain input {
         # Log dropped packets
         limit rate 5/minute log prefix "INPUT-DROP: "
       }
     }
   '';
   ```

## Updates

The router is configured for automatic security updates at 04:00 daily (no auto-reboot).

To manually update:

```bash
ssh admin@192.168.1.1
sudo nixos-rebuild switch --flake github:yourusername/yourrepo#blue-ridge
```

Or from your main machine:

```bash
nixos-rebuild switch --flake .#blue-ridge --target-host admin@192.168.1.1
```

## Comparison to OpenWRT

This configuration provides equivalent baseline features to OpenWRT:

| Feature | OpenWRT | Blue Ridge | Notes |
|---------|---------|------------|-------|
| NAT/Routing | ✓ | ✓ | nftables-based |
| DHCP Server | dnsmasq | Kea | Modern, JSON config |
| DNS Resolver | dnsmasq | Unbound | DNSSEC enabled |
| Static Leases | ✓ | ✓ | Declarative config |
| Firewall | iptables/nftables | nftables | Stateful |
| Port Forwarding | ✓ | ✓ | nftables DNAT |
| SSH Access | ✓ | ✓ | LAN-only |
| Web UI | LuCI | ✗ | CLI-only |
| Package Manager | opkg | Nix | Declarative |
| Updates | Manual | Auto | No auto-reboot |
| Impermanence | ✗ | ✓ | Ephemeral root |

### Advantages over OpenWRT
- **Impermanence**: Root filesystem wiped on boot (enhanced security)
- Declarative configuration (everything in version control)
- Atomic updates and rollbacks
- Better security hardening by default
- More powerful package ecosystem
- Easy to extend with custom modules
- Impossible for malware to persist (unless it modifies /persist or /nix)

### OpenWRT Advantages
- Web UI
- Larger router-specific community
- More wireless driver support
- Smaller disk footprint
- Simpler for non-Nix users

## Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [nixos-router project](https://github.com/chayleaf/nixos-router)
- [Kea DHCP Documentation](https://kea.readthedocs.io/)
- [Unbound Documentation](https://www.nlnetlabs.nl/documentation/unbound/)
- [nftables Wiki](https://wiki.nftables.org/)
