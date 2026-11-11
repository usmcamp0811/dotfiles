# kvmd Package

The `kvmd` package provides the PiKVM daemon and related tools for KVM over IP functionality.

## Overview

This package is the core of the PiKVM system, providing:
- The main `kvmd` daemon for managing KVM-over-IP functionality
- Supporting daemons (kvmd-ipmi, kvmd-janus, kvmd-vnc, etc.)
- Web interface files
- Configuration files and EDID data
- Helper scripts and utilities

## Package Information

- **Name**: kvmd
- **Version**: 4.234
- **Upstream**: https://github.com/pikvm/kvmd
- **License**: GPL-3.0+
- **Platforms**: Linux (primarily aarch64 for Raspberry Pi)

## Usage

This package is typically used through the `fmf.services.pikvm` module rather than directly. See the [PiKVM service module documentation](../../modules/nixos/services/pikvm/README.md) for usage examples.

### Direct Package Usage

If you need to use the package directly (e.g., for custom scripts):

```nix
{
  environment.systemPackages = [ pkgs.fmf.kvmd ];
}
```

## Available Programs

The package provides these executables:

- `kvmd` - Main KVM daemon
- `kvmd-ipmi` - IPMI-to-KVMD proxy
- `kvmd-janus` - Janus WebRTC gateway
- `kvmd-media` - Media proxy server
- `kvmd-oled` - OLED display daemon
- `kvmd-otg` - USB OTG configuration tool
- `kvmd-otgnet` - OTG network configuration
- `kvmd-pst` - Persistent storage manager
- `kvmd-vnc` - VNC proxy
- `kvmd-gencert` - Certificate generation utility
- `kvmd-edidconf` - EDID configuration tool
- Various helper scripts

## Package Structure

```
$out/
├── bin/                          # Executables
├── etc/
│   ├── kvmd/                     # Configuration files
│   │   ├── main/                 # Hardware-specific configs
│   │   │   ├── v2-hdmi-rpi4.yaml
│   │   │   ├── v3-hdmi-rpi4.yaml
│   │   │   └── ...
│   │   ├── edid/                 # EDID files
│   │   └── ...
│   ├── os/
│   │   └── udev/                 # udev rules
│   └── janus/                    # Janus Gateway config
├── share/
│   ├── kvmd/
│   │   ├── web/                  # Web interface files
│   │   ├── keymaps/              # Keyboard layout maps
│   │   └── extras/               # Service manifests
│   └── ...
└── lib/                          # Python libraries
```

## NixOS-Specific Modifications

This package includes several patches and modifications for NixOS compatibility:

### Path Substitutions

All hardcoded paths are replaced with Nix store paths:
- `/usr/bin/*` → `${package}/bin/*`
- `/usr/share/*` → `${package}/share/*`
- `/usr/lib/*` → `${package}/lib/*`
- System utilities point to nixpkgs (e.g., `${iproute2}/bin/ip`)

### Python Dependencies

All Python dependencies are managed through Nix:
- aiohttp, aiofiles, async-lru
- evdev, hidapi, pyusb, pyudev
- pillow, pyotp, qrcode
- ustreamer (with Python bindings)
- And many more (see `default.nix`)

### Janus Integration

The package includes properly patched Janus JavaScript files:
- `adapter.js` (WebRTC adapter)
- `janus.js` (with PiKVM-specific patches)

### Helper Scripts

Helper scripts are wrapped with proper PATH and include:
- `kvmd-gencert` - Certificate generation with OpenSSL

## Building

The package is built automatically as part of the fmf flake:

```bash
# Build the package
nix build .#packages.aarch64-linux.kvmd

# Build for x86_64 with cross-compilation
nix build .#packages.x86_64-linux.kvmd --system aarch64-linux
```

## Dependencies

### Build-time
- Python 3.14
- makeWrapper
- bash

### Runtime
- Python packages (see propagatedBuildInputs in default.nix)
- ustreamer (with Python support)
- janus-gateway
- v4l-utils
- systemd
- iproute2
- openssl
- libgpiod
- And others (full list in package definition)

## Hardware Support

The package supports multiple PiKVM hardware configurations:

- **v2-hdmi-rpi4** - Raspberry Pi 4 with TC358743 HDMI-CSI bridge
- **v3-hdmi-rpi4** - Raspberry Pi 4 with PiKVM v3 HAT
- **v0-hdmi** - Generic HDMI capture setup
- Other variants (see `etc/kvmd/main/` directory)

## Configuration Files

### Main Configurations

Hardware-specific YAML files in `etc/kvmd/main/`:
- Define hardware capabilities
- Video capture settings
- HID device configuration
- GPIO mappings

### EDID Files

Pre-configured EDID (Extended Display Identification Data) files for different resolutions in `etc/kvmd/edid/`.

### udev Rules

Hardware-specific udev rules in `etc/os/udev/`:
- GPIO device permissions
- Video device access
- HID device setup

## Integration with NixOS Module

The package is designed to work with the `fmf.services.pikvm` module, which:
- Manages systemd services using this package
- Generates override configuration files
- Handles user/group creation
- Configures nginx for the web interface
- Sets up proper file permissions

See [PiKVM Service Module](../../modules/nixos/services/pikvm/README.md) for complete integration details.

## Maintenance

### Updating the Package

To update to a new kvmd version:

1. Update the version and hash in `default.nix`:
   ```nix
   version = "4.XXX";
   sha256 = "sha256-...";
   ```

2. Check for new dependencies in upstream's `setup.py`

3. Update patches if needed (path substitutions)

4. Test on Raspberry Pi hardware

5. Update this README with any changes

### Testing

Test the package builds:

```bash
# Test package builds
nix build .#packages.aarch64-linux.kvmd

# Test with the module
nix build .#nixosConfigurations.test-pikvm.config.system.build.toplevel
```

## Known Issues

- **WebRTC H264**: WebRTC H264 streaming is not fully working in the current version
- **Kernel Compatibility**: `inquiry_string_cdrom` attribute is optional (newer kernels don't have it)

## Upstream

- **Source**: https://github.com/pikvm/kvmd
- **NixOS Port**: https://github.com/hatch01/nixos-pikvm
- **Documentation**: https://docs.pikvm.org

## Related

- Service Module: [modules/nixos/services/pikvm/](../../modules/nixos/services/pikvm/)
- Package Definition: [default.nix](./default.nix)
