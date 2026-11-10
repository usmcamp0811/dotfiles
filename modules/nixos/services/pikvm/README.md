# PiKVM Service Module

A comprehensive NixOS module for deploying PiKVM (KVM over IP) for remote server management and control.

## Overview

PiKVM is a platform-independent, open-source KVM (Keyboard, Video, Mouse) over IP solution that allows you to remotely manage servers and workstations through their BIOS, boot loader, and operating system. This module provides a declarative NixOS configuration for PiKVM, typically deployed on Raspberry Pi hardware but compatible with other platforms.

## Features

- **Remote KVM Access**: Full keyboard, video, and mouse control over IP
- **Virtual Media**: Mount ISO images remotely as virtual USB drives
- **IPMI Support**: IPMI proxy for compatibility with existing tools
- **WebRTC Streaming**: Low-latency video streaming via Janus Gateway
- **VNC Support**: VNC-to-KVMD proxy for traditional VNC clients
- **GPIO Control**: ATX power control via GPIO pins
- **OLED Display**: Optional OLED screen support for status display
- **Web Interface**: Full-featured web UI with Nginx
- **Declarative Configuration**: Full NixOS integration with YAML settings passthrough

## Basic Usage

### Minimal Configuration

```nix
{
  fmf.services.pikvm = {
    enable = true;
    hardwareVersion = "v2-hdmi-rpi4";
  };
}
```

### Full Configuration Example

```nix
{
  fmf.services.pikvm = {
    enable = true;
    hardwareVersion = "v2-hdmi-rpi4";
    
    user = "admin";
    passwordFile = "/run/secrets/pikvm-password";
    
    nginx = {
      enable = true;
      httpPort = 80;
      httpsPort = 443;
      httpsEnabled = true;
    };
    
    openFirewall = true;
    
    settings = {
      kvmd = {
        gpio = {
          drivers = {
            example = {
              type = "gpio";
              pin = 4;
            };
          };
          scheme = {
            power_led = {
              driver = "example";
              pin = 0;
              mode = "input";
            };
          };
        };
      };
    };
  };
  
  # Required for Raspberry Pi
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];
  
  # Firmware partition for device tree overlays
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "nofail" ];
  };
}
```

## Configuration Options

### `fmf.services.pikvm.enable`
- **Type**: `boolean`
- **Default**: `false`
- **Description**: Enable the PiKVM daemon and services

### `fmf.services.pikvm.package`
- **Type**: `package`
- **Default**: `pkgs.kvmd`
- **Description**: The kvmd package to use

### `fmf.services.pikvm.hardwareVersion`
- **Type**: `string`
- **Default**: `"v2-hdmi-rpi4"`
- **Description**: Hardware version for udev rules and configuration
- **Examples**: 
  - `"v2-hdmi-rpi4"` - Raspberry Pi 4 with TC358743 HDMI-to-CSI bridge
  - `"v3-hdmi-rpi4"` - PiKVM v3 HAT
  - `"v0-hdmi"` - Generic HDMI capture setup

### `fmf.services.pikvm.user`
- **Type**: `string`
- **Default**: `"admin"`
- **Description**: Username for PiKVM web UI authentication

### `fmf.services.pikvm.passwordFile`
- **Type**: `null or path`
- **Default**: `null`
- **Description**: Path to a file containing the plain text password for the web UI. If not set, uses the default password from the package.

### `fmf.services.pikvm.settings`
- **Type**: `YAML attribute set`
- **Default**: `{}`
- **Description**: Additional PiKVM configuration in YAML format. Merged with default configuration and written to the override config file.
- **See**: [PiKVM Configuration Documentation](https://docs.pikvm.org)

### `fmf.services.pikvm.nginx.enable`
- **Type**: `boolean`
- **Default**: `true`
- **Description**: Enable nginx web server for PiKVM

### `fmf.services.pikvm.nginx.httpPort`
- **Type**: `port`
- **Default**: `80`
- **Description**: HTTP port for nginx

### `fmf.services.pikvm.nginx.httpsPort`
- **Type**: `port`
- **Default**: `443`
- **Description**: HTTPS port for nginx

### `fmf.services.pikvm.nginx.httpsEnabled`
- **Type**: `boolean`
- **Default**: `false`
- **Description**: Enable HTTPS support (requires certificates)

### `fmf.services.pikvm.openFirewall`
- **Type**: `boolean`
- **Default**: `true`
- **Description**: Open firewall ports for kvmd web interface

## Hardware Requirements

### Raspberry Pi 4 (Recommended)

- Raspberry Pi 4 (2GB RAM minimum, 4GB recommended)
- HDMI-to-CSI bridge (TC358743-based) or PiKVM v3 HAT
- MicroSD card (32GB or larger recommended)
- USB-C cable for HID emulation
- Power supply

### Storage Partitions

PiKVM requires two additional partitions beyond the standard NixOS root:

1. **PIMSD** - Virtual USB drive storage
   - Label: `PIMSD`
   - Type: ext4
   - Recommended size: 50GB (for ISO storage)
   - Mount point: `/var/lib/kvmd/msd`

2. **PIPST** - PiKVM persistent storage
   - Label: `PIPST`
   - Type: ext4
   - Recommended size: 256MB minimum
   - Mount point: `/var/lib/kvmd/pst`

These are automatically mounted by the module.

## Services

The module manages multiple systemd services:

- **kvmd** - Main PiKVM daemon
- **kvmd-ipmi** - IPMI-to-KVMD proxy
- **kvmd-janus** - Janus WebRTC Gateway for video streaming
- **kvmd-media** - Media proxy server for virtual drives
- **kvmd-oled** - OLED display daemon (conditional)
- **kvmd-otg** - USB OTG setup
- **kvmd-pst** - Persistent storage manager
- **kvmd-tc358743** - EDID loader for TC358743 (Raspberry Pi only)
- **kvmd-vnc** - VNC-to-KVMD/Streamer proxy

## Users and Groups

The module automatically creates:

### Users
- `kvmd` - Main daemon user (groups: kvmd, gpio, video, input, tty)
- `kvmd-ipmi` - IPMI proxy user
- `kvmd-janus` - Janus Gateway user
- `kvmd-localhid` - Local HID user
- `kvmd-media` - Media server user
- `kvmd-pst` - Persistent storage user
- `kvmd-vnc` - VNC proxy user

### Groups
- `kvmd` - Main group
- `kvmd-ipmi`, `kvmd-janus`, `kvmd-localhid`, `kvmd-media`, `kvmd-pst`, `kvmd-vnc` - Service-specific groups
- `gpio` - GPIO access group

## Security

### Password Management

The module supports secure password configuration via `passwordFile`:

```nix
{
  fmf.services.pikvm.passwordFile = "/run/secrets/pikvm-password";
}
```

The password file should contain only the password (trailing newline is automatically trimmed). The module generates an SSHA512 hash suitable for htpasswd.

### Vault Integration

For environments using HashiCorp Vault, combine with `fmf.services.vault-agent`:

```nix
{
  fmf.services.vault-agent = {
    enable = true;
    settings.vault = {
      address = "http://vault.example.com:8200";
      role-id = "/var/lib/vault/pikvm/role-id";
      secret-id = "/var/lib/vault/pikvm/secret-id";
    };
  };
  
  fmf.services.pikvm = {
    enable = true;
    passwordFile = "/var/lib/vault/secrets/pikvm-password";
  };
}
```

### Sudo Permissions

The module configures passwordless sudo access for specific helper scripts:
- `kvmd` user can run `kvmd-helper-otgmsd-remount` and `kvmd-helper-pst-remount`
- `kvmd-pst` user can run `kvmd-helper-pst-remount`

## Building for ARM on x86_64 Systems

Since PiKVM runs on Raspberry Pi (aarch64 architecture), but most development systems are x86_64, you need to cross-build or emulate. Here are your options:

### Option 1: QEMU Emulation (Recommended for most users)

**Pros**: Works on any NixOS system, no additional hardware needed  
**Cons**: Slow (2-4 hour builds)

#### Setup

Add to your NixOS configuration:

```nix
{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  nix.settings.extra-platforms = [ "aarch64-linux" ];
}
```

Apply the configuration:

```bash
sudo nixos-rebuild switch
```

That's it! Now you can build ARM images directly.

### Option 2: Remote Builder (Fastest)

**Pros**: Native ARM speed, builds in minutes  
**Cons**: Requires access to an ARM machine

#### Setup

If you have any ARM-based NixOS machine (Raspberry Pi, ARM server, etc.):

1. **On the ARM machine**, ensure SSH and nix are properly configured:

```nix
{
  nix.settings.trusted-users = [ "your-user" ];
  services.openssh.enable = true;
}
```

2. **On your x86_64 build machine**, configure the remote builder:

```nix
# Add to /etc/nix/nix.conf or ~/.config/nix/nix.conf
builders = ssh://user@arm-host aarch64-linux - 4
builders-use-substitutes = true
```

Or use the `--builders` flag when building:

```bash
nix build --builders "ssh://user@arm-host aarch64-linux" ...
```

3. **Ensure SSH key authentication** is set up:

```bash
ssh-copy-id user@arm-host
```

Builds will now automatically use the ARM machine.

### Option 3: Binary Cache

**Pros**: Instant if someone has already built it  
**Cons**: May not have your specific configuration

If using a shared binary cache:

```nix
{
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
```

### Option 4: GitHub Actions CI

**Pros**: No local resources needed, reproducible  
**Cons**: Requires GitHub setup, still slow due to emulation

Create `.github/workflows/build-pikvm.yml`:

```yaml
name: Build PiKVM Image

on:
  push:
    paths:
      - 'systems/**/pikvm/**'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: cachix/install-nix-action@v24
        with:
          extra_nix_config: |
            extra-platforms = aarch64-linux
      
      - uses: docker/setup-qemu-action@v3
        with:
          platforms: arm64
      
      - name: Build PiKVM Image
        run: |
          nix run nixpkgs#nixos-generators -- \
            -f sd-aarch64 \
            --flake .#pikvm \
            --system aarch64-linux \
            -o ./pikvm-image
      
      - uses: actions/upload-artifact@v4
        with:
          name: pikvm-sd-image
          path: ./pikvm-image/sd-image/*.img*
```

### Performance Comparison

| Method | Typical Build Time | Setup Difficulty | Requirements |
|--------|-------------------|------------------|--------------|
| QEMU Emulation | 2-4 hours | Easy | NixOS config change |
| Remote ARM Builder | 10-30 minutes | Medium | ARM machine access |
| Binary Cache | Seconds | Easy | Cache availability |
| CI/CD | 2-4 hours | Medium | GitHub account |

### Troubleshooting

#### "unsupported system type aarch64-linux"

Enable binfmt emulation or add a remote builder (see options above).

Quick fix:
```bash
nix build --extra-platforms aarch64-linux --system aarch64-linux ...
```

#### Build extremely slow

You're using QEMU emulation. This is normal. Options:
- Use a remote ARM builder
- Build overnight
- Use CI/CD
- Try a binary cache

#### "cannot build derivation on wrong platform"

Some packages don't support cross-compilation. Use QEMU emulation or remote builder.

#### Out of disk space

```bash
# Free up space
nix-collect-garbage -d

# Check available space (need 20-30GB)
df -h /nix
```

## Installation

**Note**: If building on an x86_64 system, see the [Building for ARM on x86_64 Systems](#building-for-arm-on-x86_64-systems) section above first.

### 1. Generate SD Card Image

```bash
# This will use QEMU emulation if you've enabled it, or a remote builder if configured
nix run nixpkgs#nixos-generators -- \
  -f sd-aarch64 \
  --flake .#pikvm \
  --system aarch64-linux \
  -o ./pikvm-sd-aarch64
```

### 2. Flash to SD Card

```bash
# Using dd
sudo dd if=./pikvm-sd-aarch64/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync

# Or using Caligula
nix run github:ifd3f/caligula -- ./pikvm-sd-aarch64/sd-image/*.img
```

### 3. Create Additional Partitions

After flashing, create the PIMSD and PIPST partitions:

```bash
sudo fdisk /dev/sdX
# Create two new partitions with remaining space

sudo mkfs.ext4 -L PIMSD /dev/sdX3
sudo mkfs.ext4 -L PIPST /dev/sdX4
```

Expected layout:
```
/dev/sdX1  FIRMWARE   30M   (vfat)
/dev/sdX2  NIXOS_SD   ~70G  (ext4)
/dev/sdX3  PIMSD      50G   (ext4)
/dev/sdX4  PIPST      256M  (ext4)
```

### 4. Boot and Access

1. Insert SD card into Raspberry Pi
2. Connect HDMI capture to target server
3. Connect USB cable from Pi to target server
4. Power on
5. Access web interface at http://pikvm-ip-address

## Advanced Configuration

### GPIO ATX Control

Configure GPIO pins for power button and LED control:

```nix
{
  fmf.services.pikvm.settings = {
    kvmd.gpio = {
      drivers = {
        rpi = {
          type = "gpio";
        };
      };
      scheme = {
        power_led = {
          driver = "rpi";
          pin = 24;
          mode = "input";
        };
        hdd_led = {
          driver = "rpi";
          pin = 22;
          mode = "input";
        };
        power_switch = {
          driver = "rpi";
          pin = 23;
          mode = "output";
          switch = false;
        };
        reset_switch = {
          driver = "rpi";
          pin = 27;
          mode = "output";
          switch = false;
        };
      };
    };
  };
}
```

### HTTPS with Custom Certificates

```nix
{
  fmf.services.pikvm.nginx = {
    enable = true;
    httpsEnabled = true;
    httpsPort = 443;
  };
  
  # Add SSL certificate configuration to nginx
  services.nginx.virtualHosts."pikvm" = {
    sslCertificate = "/path/to/cert.pem";
    sslCertificateKey = "/path/to/key.pem";
  };
}
```

Or generate self-signed certificates using the included script:

```bash
ssh admin@pikvm
sudo kvmd-gencert
```

### Custom Video Settings

```nix
{
  fmf.services.pikvm.settings = {
    kvmd.streamer = {
      resolution = {
        default = "1920x1080";
      };
      quality = 80;
      desired_fps = {
        default = 30;
      };
    };
  };
}
```

## Troubleshooting

### Service Won't Start

Check service status and logs:

```bash
systemctl status kvmd
journalctl -u kvmd -xe
```

### Video Not Working

Verify HDMI capture device:

```bash
ls -la /dev/video*
v4l2-ctl --device=/dev/video0 --info
```

For Raspberry Pi, check that TC358743 service loaded the EDID:

```bash
systemctl status kvmd-tc358743
```

### Permission Issues

Verify user groups:

```bash
groups kvmd
# Should include: kvmd gpio video input tty
```

### Web Interface Not Accessible

Check nginx and firewall:

```bash
systemctl status nginx
nft list ruleset | grep 80
```

## Updating

Deploy configuration changes:

```bash
nixos-rebuild switch --flake .#pikvm --target-host admin@pikvm-ip
```

## References

- **PiKVM Official Documentation**: https://docs.pikvm.org
- **PiKVM GitHub**: https://github.com/pikvm/kvmd
- **nixos-pikvm**: https://github.com/hatch01/nixos-pikvm
- **Package Source**: `packages/packages/kvmd/default.nix`

## Example Deployments

### Basic Raspberry Pi KVM

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];
  
  fmf.services.pikvm = {
    enable = true;
    hardwareVersion = "v2-hdmi-rpi4";
    openFirewall = true;
  };
  
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "nofail" ];
  };
}
```

### PiKVM with Vault and HTTPS

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];
  
  fmf.services = {
    pikvm = {
      enable = true;
      hardwareVersion = "v2-hdmi-rpi4";
      passwordFile = "/var/lib/vault/secrets/pikvm-password";
      
      nginx = {
        enable = true;
        httpsEnabled = true;
      };
      
      openFirewall = true;
    };
    
    vault-agent = {
      enable = true;
      settings = {
        vault = {
          address = "http://10.8.0.3:8200";
          role-id = "/var/lib/vault/pikvm/role-id";
          secret-id = "/var/lib/vault/pikvm/secret-id";
        };
      };
    };
  };
  
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "nofail" ];
  };
}
```

### PiKVM with ATX Control

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];
  
  fmf.services.pikvm = {
    enable = true;
    hardwareVersion = "v2-hdmi-rpi4";
    
    settings = {
      kvmd.gpio = {
        drivers.rpi.type = "gpio";
        scheme = {
          power_led = {
            driver = "rpi";
            pin = 24;
            mode = "input";
          };
          power_switch = {
            driver = "rpi";
            pin = 23;
            mode = "output";
            switch = false;
            pulse.delay = 0.1;
          };
          reset_switch = {
            driver = "rpi";
            pin = 27;
            mode = "output";
            switch = false;
            pulse.delay = 0.1;
          };
        };
      };
    };
  };
  
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "nofail" ];
  };
}
```

## Architecture Notes

- The module follows fmf service patterns with the `fmf.services.pikvm` namespace
- Raspberry Pi hardware support is conditional based on `hardwareVersion`
- The module integrates with nixos-hardware for Raspberry Pi device trees
- Configuration is managed via YAML generation with sensible defaults
- All services are managed by systemd with proper dependencies
- Filesystem mounts are automatic when PIMSD/PIPST partitions exist
