# Disko Package - Declarative Disk Partitioning

Automated disk partitioning for NixOS systems using [disko](https://github.com/nix-community/disko).

## Quick Start

### From Anywhere (Live USB, etc.)

No cloning needed! The flake source (including disko configs) is automatically fetched to the Nix store:

```bash
# Show help and available systems
nix run gitlab:usmcamp0811/dotfiles#disko

# Partition blue-ridge system
nix run gitlab:usmcamp0811/dotfiles#disko -- blue-ridge

# Or use the shortcut
nix run gitlab:usmcamp0811/dotfiles#disko-blue-ridge
```

### From Local Clone (if developing)

```bash
# Clone repo
git clone https://gitlab.com/usmcamp0811/dotfiles.git
cd dotfiles

# Show help
nix run .#disko

# Run disko for blue-ridge
nix run .#disko -- blue-ridge

# Or use the shortcut
nix run .#disko-blue-ridge
```

**Note:** The disko configs are embedded in the package at build time, so this works from any directory!

## Usage

```bash
nix run .#disko -- [SYSTEM_NAME] [OPTIONS]
```

### Options

- `--help` - Show help message
- `--mode MODE` - Disko mode (disko, format, mount, dryDisko). Default: disko
- `--encrypted` - Use encrypted disko config (disko-encrypted.nix)
- `--disk DEVICE` - Override disk device (default: /dev/sda)

### Examples

```bash
# Dry run (show what would be done, no changes)
nix run .#disko -- blue-ridge --mode dryDisko

# Use encrypted configuration
nix run .#disko -- blue-ridge --encrypted

# Use different disk device
nix run .#disko -- blue-ridge --disk /dev/nvme0n1

# Just mount existing partitions
nix run .#disko -- blue-ridge --mode mount
```

## Available Systems

### blue-ridge
Intel N100 Router with 238GB SSD
- Config: `systems/x86_64-linux/blue-ridge/disko.nix`
- Encrypted: `systems/x86_64-linux/blue-ridge/disko-encrypted.nix`

## Workflow

### Standard Installation

```bash
# 1. Boot from NixOS installer USB

# 2. Run disko (WARNING: Erases disk!)
nix run gitlab:usmcamp0811/dotfiles#disko -- blue-ridge

# 3. Create persist directories
mkdir -p /mnt/persist/system
mkdir -p /mnt/persist/home/admin

# 4. Install NixOS
nixos-install --flake gitlab:usmcamp0811/dotfiles#blue-ridge

# 5. Reboot
reboot
```

### Encrypted Installation

```bash
# 1. Boot from NixOS installer USB

# 2. Run disko with encryption (will generate key automatically)
nix run gitlab:usmcamp0811/dotfiles#disko -- blue-ridge --encrypted

# 3. Save the encryption key shown (IMPORTANT!)
#    The key is displayed in base64 - save it somewhere safe!

# 4. Copy key to boot partition
cp /tmp/persist.key /mnt/boot/persist.key
chmod 600 /mnt/boot/persist.key

# 5. Create persist directories
mkdir -p /mnt/persist/system
mkdir -p /mnt/persist/home/admin

# 6. Install NixOS
nixos-install --flake gitlab:usmcamp0811/dotfiles#blue-ridge

# 7. Reboot
reboot
```

## Safety Features

### Dry Run First
Always test with `--mode dryDisko` first:
```bash
nix run .#disko -- blue-ridge --mode dryDisko
```

### Confirmation Prompts
The script will:
1. Show current disk layout with `lsblk`
2. Require typing "yes" to confirm destructive operations
3. For encrypted configs, warn about key backup

### Encryption Key Management
For encrypted configs:
- Key is auto-generated at `/tmp/persist.key`
- Key is displayed in base64 for backup
- Script pauses to let you save the key
- Without the key, encrypted data is **permanently unrecoverable**

## Adding New Systems

To add disko support for a new system:

1. Create the disko config:
   ```bash
   # Standard config
   touch systems/x86_64-linux/NEW_SYSTEM/disko.nix

   # Or encrypted config
   touch systems/x86_64-linux/NEW_SYSTEM/disko-encrypted.nix
   ```

2. The script will auto-discover it - no other changes needed!

3. (Optional) Create a convenience shortcut:
   ```bash
   # Create packages/disko-NEW_SYSTEM/default.nix
   # Copy from packages/disko-blue-ridge/default.nix and adjust name
   ```

## Disko Modes

- **disko** - Partition, format, and mount (destructive)
- **format** - Format existing partitions
- **mount** - Mount existing partitions
- **dryDisko** - Show what would be done (safe, for testing)

## Troubleshooting

### Config Not Found
```bash
Error: Disko config not found
```
**Solution:** Make sure you're running from a system with a disko config in `systems/x86_64-linux/{system}/disko.nix`

### Wrong Disk Device
```bash
# Override with --disk
nix run .#disko -- blue-ridge --disk /dev/nvme0n1
```

### Mount Errors
```bash
# Unmount everything first
sudo umount -R /mnt

# Try again
nix run .#disko -- blue-ridge
```

### Missing Encryption Key
For encrypted configs, the key must be at `/tmp/persist.key` before running disko.

Generate manually:
```bash
dd if=/dev/random of=/tmp/persist.key bs=1024 count=4
chmod 600 /tmp/persist.key
```

## Under the Hood

The script:
1. Uses the flake source path embedded at build time (in the Nix store)
2. Locates the disko config in `systems/x86_64-linux/{system}/` within that source
3. Shows current disk layout with `lsblk`
4. Confirms destructive operations
5. Runs `nix run github:nix-community/disko` with your config
6. Shows next steps

**Key Detail:** When you run `nix run gitlab:usmcamp0811/dotfiles#disko`, Nix:
- Fetches the flake source to `/nix/store/...`
- Builds the disko package with `FLAKE_ROOT` pointing to that store path
- The disko configs (like `systems/x86_64-linux/blue-ridge/disko.nix`) are in that store path
- Everything works without cloning!

## Related Files

- Main script: `packages/disko/default.nix`
- Per-system shortcuts: `packages/disko-{system}/default.nix`
- Disko configs: `systems/x86_64-linux/{system}/disko*.nix`
- Installation guides: `systems/x86_64-linux/{system}/INSTALL.md`

## References

- [Disko Documentation](https://github.com/nix-community/disko)
- [Disko Examples](https://github.com/nix-community/disko/tree/master/example)
- [Blue Ridge Install Guide](../../systems/x86_64-linux/blue-ridge/INSTALL.md)
