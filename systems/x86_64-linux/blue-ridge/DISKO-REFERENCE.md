# Disko Quick Reference for Blue Ridge

## What is Disko?

Disko is a declarative disk partitioning tool for NixOS that allows you to define your entire disk layout in Nix configuration. It automates partitioning, formatting, and mounting.

## Blue Ridge Disk Configuration

Location: `systems/x86_64-linux/blue-ridge/disko.nix`

### Partition Layout

| Partition | Size   | Type       | Mount Point | Label   | Purpose                          |
|-----------|--------|------------|-------------|---------|----------------------------------|
| sda1      | 1MB    | BIOS boot  | -           | -       | Legacy BIOS boot support         |
| sda2      | 1GB    | vfat       | /boot       | ESP     | UEFI boot partition              |
| sda3      | 180GB  | ext4       | /nix        | nix     | Nix store (persistent)           |
| sda4      | 50GB   | ext4       | /persist    | persist | Persistent data                  |
| sda5      | ~7.5GB | swap       | -           | swap    | Swap space                       |
| (tmpfs)   | 2GB    | tmpfs      | /           | -       | Ephemeral root (wiped on boot)   |

## Installation Commands

### From NixOS Installer

```bash
# 1. Boot NixOS installer USB

# 2. Get your configuration
nix-shell -p git
git clone https://github.com/yourusername/yourconfig.git /tmp/config
cd /tmp/config

# 3. Run disko (WARNING: Erases /dev/sda!)
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko \
  /tmp/config/systems/x86_64-linux/blue-ridge/disko.nix

# 4. Create persist directories
mkdir -p /mnt/persist/system
mkdir -p /mnt/persist/home/admin

# 5. Install NixOS
sudo nixos-install --flake /tmp/config#blue-ridge

# 6. Reboot
reboot
```

### Testing Disko Configuration

Test the configuration without actually partitioning:

```bash
# Dry run - shows what would be done
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode dryDisko \
  systems/x86_64-linux/blue-ridge/disko.nix
```

### Different Disko Modes

1. **disko** - Partition, format, and mount (destructive)
   ```bash
   --mode disko
   ```

2. **dryDisko** - Show what would be done (safe, for testing)
   ```bash
   --mode dryDisko
   ```

3. **mount** - Mount already-existing partitions
   ```bash
   --mode mount
   ```

4. **format** - Format existing partitions
   ```bash
   --mode format
   ```

## Modifying the Partition Layout

Edit `systems/x86_64-linux/blue-ridge/disko.nix` to change partition sizes:

```nix
# Example: Make /nix larger, /persist smaller
nix = {
  size = "200G";  # Changed from 180G
  content = {
    type = "filesystem";
    format = "ext4";
    mountpoint = "/nix";
  };
};

persist = {
  size = "30G";   # Changed from 50G
  # ...
};
```

**After modifying:** You must repartition (destructive) or expand partitions manually.

## Filesystem Labels

Disko automatically creates these labels (referenced in `hardware.nix`):

- `ESP` - Boot partition (vfat)
- `nix` - Nix store (ext4)
- `persist` - Persistent data (ext4)
- `swap` - Swap partition

Verify labels after installation:
```bash
lsblk -f
```

## Advanced: Encrypted Partitions

To add LUKS encryption to the nix and persist partitions, modify `disko.nix`:

```nix
nix = {
  size = "180G";
  content = {
    type = "luks";
    name = "crypted-nix";
    settings.allowDiscards = true;
    passwordFile = "/tmp/secret.key";  # Or prompt interactively
    content = {
      type = "filesystem";
      format = "ext4";
      mountpoint = "/nix";
    };
  };
};
```

## Troubleshooting

### Disk Not Found

If disko can't find `/dev/sda`:

```bash
# Check actual disk name
lsblk

# Edit disko.nix to use correct disk
device = "/dev/nvme0n1";  # or whatever your disk is
```

### Labels Don't Match

If hardware.nix expects different labels:

```bash
# Check current labels
lsblk -f

# Either update disko.nix labels or hardware.nix device paths
```

### Partition Already Exists

If disk was previously partitioned:

```bash
# Wipe partition table first
sudo wipefs -a /dev/sda

# Then run disko again
```

### Mount Errors

If disko fails to mount:

```bash
# Check what's mounted
mount | grep /mnt

# Unmount everything
sudo umount -R /mnt

# Try again
```

## Integration with NixOS Configuration

The disko config is separate from your NixOS config. Workflow:

1. **Installation time**: Run disko to partition/format
2. **Runtime**: `hardware.nix` references the created partitions by label
3. **Rebuilds**: No need to run disko again (partitions persist)

### Importing Disko Module (Optional)

You can import disko as a NixOS module for documentation:

```nix
# In flake.nix
{
  inputs.disko.url = "github:nix-community/disko";

  # In system configuration
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];
}
```

But this is **not required** for installation - disko is primarily a partitioning tool.

## Backup Before Repartitioning

Always backup before running disko:

```bash
# Backup partition table
sudo sfdisk -d /dev/sda > partition-table-backup.txt

# Backup important data
rsync -avz /old/persist/ /backup/location/
```

## Related Files

- `disko.nix` - Disk partitioning configuration
- `hardware.nix` - Hardware and filesystem configuration
- `INSTALL.md` - Full installation guide
- `impermanence.nix` - What gets persisted across reboots

## References

- [Disko Documentation](https://github.com/nix-community/disko)
- [Disko Examples](https://github.com/nix-community/disko/tree/master/example)
- [NixOS Impermanence Guide](https://github.com/nix-community/impermanence)
