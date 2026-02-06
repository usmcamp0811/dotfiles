# Blue Ridge Networking Recovery Guide

## Problem: No networking after installation

The router module is disabled in the configuration, so no networking is set up.

## Quick Fix

### Option 1: Enable Router Module (Recommended)

Edit `/config/systems/x86_64-linux/blue-ridge/default.nix`:

```nix
router = {
  enable = true;  # ← UNCOMMENT THIS LINE!

  wan = {
    interface = "enp1s0";
    # ...
  };
  # ...
};
```

Then rebuild:
```bash
sudo nixos-rebuild switch --flake .#blue-ridge
```

### Option 2: Emergency Network Access (If you have no network to rebuild)

#### Step 1: Boot into recovery/single-user mode

Add `systemd.unit=rescue.target` to kernel boot parameters.

#### Step 2: Identify your network interfaces

```bash
ip link show
```

Look for interfaces like `enp1s0`, `enp2s0`, `enp3s0`, `enp4s0` or similar.

#### Step 3: Manually bring up networking temporarily

**For WAN (get internet access):**
```bash
# Replace enp1s0 with your actual WAN interface
ip link set enp1s0 up
dhcpcd enp1s0
```

**Or with systemd-networkd:**
```bash
# Create temporary config
cat > /etc/systemd/network/50-wan.network <<EOF
[Match]
Name=enp1s0

[Network]
DHCP=yes
EOF

systemctl restart systemd-networkd
```

#### Step 4: Once you have network, fix the configuration

```bash
cd /path/to/config
nano systems/x86_64-linux/blue-ridge/default.nix

# Uncomment: enable = true;

sudo nixos-rebuild switch --flake .#blue-ridge
```

## Root Cause Analysis

The router configuration has `campground.router.enable` commented out:

```nix
router = {
  # enable = true;  ← THIS IS THE PROBLEM
  wan = { ... };
  lan = { ... };
};
```

When `enable = false` (default), the router module does:
- ❌ No systemd-networkd configuration
- ❌ No WAN interface setup
- ❌ No LAN bridge creation
- ❌ No DHCP server
- ❌ No DNS resolver
- ❌ No firewall/NAT

Meanwhile, the config also has:
```nix
networking.networkmanager.enable = mkForce false;
networking.useDHCP = mkForce false;
networking.firewall.enable = mkForce false;
```

This disables all alternative networking, leaving the system with **NO network configuration at all**.

## Permanent Fix

### 1. Update blue-ridge configuration

```nix
campground.router = {
  enable = true;  # ← MUST be true!

  wan = {
    interface = "enp1s0";  # Verify with: ip link
    dhcp = true;
  };

  lan = {
    interfaces = ["enp2s0" "enp3s0" "enp4s0"];  # Verify with: ip link
    subnet = "192.168.1.0/24";
    gateway = "192.168.1.1";
  };

  # ... rest of config
};
```

### 2. Verify interface names

After installation, the actual interface names might be different. Check with:

```bash
ip link show

# You might see:
# - eno1, eno2, eno3, eno4 (onboard NICs)
# - enp1s0, enp2s0, enp3s0, enp4s0 (PCI location)
# - eth0, eth1, eth2, eth3 (old naming)
```

Update your config to match reality.

### 3. Add fallback networking

For safety during development, add a fallback:

```nix
# In blue-ridge/default.nix
systemd.network.networks."99-fallback-dhcp" = lib.mkIf (!config.campground.router.enable) {
  matchConfig.Name = "en*";  # Match any ethernet
  networkConfig.DHCP = "yes";
};

networking.useNetworkd = true;  # Ensure systemd-networkd is used
```

## Testing

After fixing:

```bash
# Check systemd-networkd is running
systemctl status systemd-networkd

# Check interfaces are up
ip link show

# Check WAN has IP
ip addr show enp1s0  # or your WAN interface

# Check LAN bridge exists
ip link show br-lan

# Check LAN bridge has IP
ip addr show br-lan | grep "192.168.1.1"

# Test DNS
dig @192.168.1.1 google.com

# Test internet from router
ping -c 3 1.1.1.1
```

## Prevention

To avoid this in the future:

### Add a NixOS check

Create `systems/x86_64-linux/blue-ridge/checks.nix`:

```nix
{ config, lib, ... }:

{
  # Assertion: Router must be enabled
  assertions = [
    {
      assertion = config.campground.router.enable;
      message = ''
        ERROR: campground.router.enable is false!
        The blue-ridge router system requires the router module to be enabled.
        Set: campground.router.enable = true;
      '';
    }
  ];

  # Warning: Check interface configuration
  warnings = lib.optionals config.campground.router.enable [
    (lib.mkIf (config.campground.router.wan.interface == "enp1s0") ''
      Router WAN interface is set to "enp1s0" - verify this matches your hardware.
      Run 'ip link show' to check actual interface names.
    '')
  ];
}
```

Import in `default.nix`:
```nix
imports = [
  ./hardware.nix
  ./impermanence.nix
  ./checks.nix  # ← Add this
];
```

## Alternative: USB Network Installer

If you can't access the system, create a bootable USB with network access:

```bash
# On your main machine
nix-shell -p nixos-generators

# Create installer with SSH
nixos-generate -f install-iso -c /path/to/config/systems/x86_64-linux/blue-ridge/installer.nix
```

Where `installer.nix` contains:
```nix
{ pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  # Enable networking
  networking.useDHCP = true;
  networking.wireless.enable = false;

  # Enable SSH
  services.openssh.enable = true;
  users.users.root.password = "installer";

  # Include your SSH keys
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3... your-key"
  ];
}
```

## Summary

**Problem:** `campground.router.enable` was commented out/false
**Solution:** Set `campground.router.enable = true;`
**Prevention:** Add assertions to catch this at build time

The router module handles ALL networking - if it's disabled, you get no network at all.
