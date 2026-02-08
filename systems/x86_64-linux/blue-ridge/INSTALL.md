# Blue Ridge Router Installation Guide with Impermanence

This guide covers installing NixOS on the blue-ridge router with impermanence enabled.

**Two installation methods:**
1. **Automated with Disko** (recommended) - Uses declarative disk partitioning
2. **Manual partitioning** - Traditional manual setup (see below)

## What is Impermanence?

Impermanence makes your root filesystem ephemeral - it's wiped on every boot. Only specific directories in `/persist` and the Nix store survive reboots. This provides:

- **Enhanced Security**: Malware can't persist across reboots
- **Cleaner System**: No accumulation of temporary files or state
- **Declarative Everything**: Forces you to declare all important state
- **Easy Recovery**: System always boots to a known-good state

## Disk Layout

The router will use the following partition layout:

```
/dev/sda1  1MB     BIOS     (BIOS boot partition)
/dev/sda2  1GB     FAT32   /boot      (EFI System Partition)
/dev/sda3  180GB   ext4    /nix       (Nix store - persistent)
/dev/sda4  50GB    ext4    /persist   (State that survives reboots)
/dev/sda5  ~7.5GB  swap             (Swap partition)
/          2GB     tmpfs   /          (Ephemeral root, wiped on boot)
```

## Prerequisites

1. NixOS installation media (USB stick)
2. Access to the router via monitor/keyboard or serial console
3. Your SSH public key ready
4. Password hash generated (run `mkpasswd -m sha-512`)

## Installation Method 1: Automated with Disko (Recommended)

### 1. Boot from NixOS Installation Media

Download and write NixOS minimal ISO to USB:

```bash
# On your main machine
wget https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso
dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress
```

Boot the router from the USB stick.

### 2. Setup Network and Get Configuration

```bash
# Setup network (adjust for your setup)
# For DHCP (if available during install):
systemctl start NetworkManager
nmcli device wifi connect "YOUR_SSID" password "YOUR_PASSWORD"

# Or use wired connection (should work automatically)

# Clone your configuration repo
nix-shell -p git
git clone https://github.com/yourusername/yourconfig.git /tmp/config
cd /tmp/config
```

### 3. Partition with Disko

**IMPORTANT**: This will ERASE ALL DATA on /dev/sda!

```bash
# Verify the target disk
lsblk

# Run disko to partition and format the disk
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko \
  /tmp/config/systems/x86_64-linux/blue-ridge/disko.nix

# This will:
# - Partition /dev/sda with GPT
# - Create and format all partitions
# - Mount everything under /mnt
```

### 4. Create Persist Directories

```bash
# Create necessary directories in /persist
mkdir -p /mnt/persist/system
mkdir -p /mnt/persist/home/admin
```

### 5. Install NixOS

```bash
# Install using your flake configuration
sudo nixos-install --flake /tmp/config#blue-ridge

# Set root password when prompted (temporary, for initial access)
```

### 6. Reboot

```bash
# Remove USB stick and reboot
reboot
```

Now skip to **Post-Installation Setup** below.

---

## Installation Method 2: Manual Partitioning

### 1. Boot from NixOS Installation Media

Download and write NixOS minimal ISO to USB:

```bash
# On your main machine
wget https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso
dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress
```

Boot the router from the USB stick.

### 2. Partition the Disk

**IMPORTANT**: This will ERASE ALL DATA on the disk!

```bash
# Identify your disk (usually /dev/sda or /dev/nvme0n1)
lsblk

# Set disk variable (adjust if needed)
DISK=/dev/sda

# Partition the disk
parted $DISK -- mklabel gpt

# Create BIOS boot partition (1MB)
parted $DISK -- mkpart primary 1MiB 2MiB
parted $DISK -- set 1 bios_grub on

# Create EFI boot partition (1GB)
parted $DISK -- mkpart ESP fat32 2MiB 1026MiB
parted $DISK -- set 2 esp on

# Create Nix store partition (180GB)
parted $DISK -- mkpart primary ext4 1026MiB 181274MiB

# Create persist partition (50GB)
parted $DISK -- mkpart primary ext4 181274MiB 232522MiB

# Create swap partition (remaining space)
parted $DISK -- mkpart primary linux-swap 232522MiB 100%
```

### 3. Format the Partitions

```bash
# Format with labels (these must match hardware.nix and disko.nix)
mkfs.fat -F 32 -n ESP ${DISK}2
mkfs.ext4 -L nix ${DISK}3
mkfs.ext4 -L persist ${DISK}4
mkswap -L swap ${DISK}5

# Verify labels
lsblk -f
```

You should see:
```
NAME   FSTYPE LABEL
sda1
sda2   vfat   ESP
sda3   ext4   nix
sda4   ext4   persist
sda5   swap   swap
```

### 4. Mount the Filesystems

```bash
# Mount in the correct order
mount -t tmpfs none /mnt

# Create mount points
mkdir -p /mnt/{boot,nix,persist}

# Mount persistent partitions
mount /dev/disk/by-label/ESP /mnt/boot
mount /dev/disk/by-label/nix /mnt/nix
mount /dev/disk/by-label/persist /mnt/persist

# Enable swap
swapon /dev/disk/by-label/swap

# Create necessary directories on persist
mkdir -p /mnt/persist/system
mkdir -p /mnt/persist/home/admin

# Verify mounts
mount | grep /mnt
```

### 5. Generate Initial Configuration

```bash
# Generate hardware config
nixos-generate-config --root /mnt

# The generated hardware-configuration.nix will be wrong (it doesn't know about tmpfs root)
# We'll replace it with our config later
```

### 6. Clone Your Configuration

If you have network access during installation:

```bash
# Get network (if using WiFi)
# systemctl start wpa_supplicant
# wpa_cli

# Clone your repo
cd /mnt
nix-shell -p git
git clone https://github.com/yourusername/yourrepo.git /mnt/etc/nixos/config

# Or copy from USB stick if you brought your config
```

### 7. Install NixOS

```bash
# Install using your flake
nixos-install --flake /mnt/etc/nixos/config#blue-ridge

# Or if you can't clone, use a minimal config first:
```

**Minimal bootstrap config** (if needed):

Create `/mnt/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Impermanence filesystems (override generated config)
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "size=2G" "mode=755" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nix";
    fsType = "ext4";
    neededForBoot = true;
    options = [ "noatime" ];
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-label/persist";
    fsType = "ext4";
    neededForBoot = true;
    options = [ "noatime" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];

  networking.hostName = "blue-ridge";
  networking.useDHCP = true;

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    password = "nixos"; # Change immediately!
  };

  security.sudo.wheelNeedsPassword = false; # Temporary!

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  environment.systemPackages = with pkgs; [ vim git ];

  system.stateVersion = "25.11";
}
```

Then install:

```bash
nixos-install
```

### 8. Set Root Password (Temporary)

```bash
# During installation, you'll be prompted to set root password
# This is only for initial setup
```

### 9. Reboot

```bash
# Remove installation media
reboot
```

## Post-Installation Setup

### 1. First Boot - Configure SSH

After reboot, log in as `admin` (or root if using minimal config).

```bash
# Create SSH directory in persist
mkdir -p /persist/home/admin/.ssh
chmod 700 /persist/home/admin/.ssh

# Add your public key
cat > /persist/home/admin/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-key-here
EOF

chmod 600 /persist/home/admin/.ssh/authorized_keys
chown -R admin:users /persist/home/admin/.ssh
```

### 2. Deploy Full Configuration

From your main machine:

```bash
# Update the configuration with your details:
# 1. Add SSH key to systems/x86_64-linux/blue-ridge/default.nix
# 2. Set password hash
# 3. Configure interface names (check with `ip link` on router)
# 4. Adjust network settings if needed

# Deploy the full configuration
nixos-rebuild switch --flake .#blue-ridge --target-host admin@<router-ip>

# Or from the router itself:
cd /etc/nixos/config  # or wherever you cloned it
sudo nixos-rebuild switch --flake .#blue-ridge
```

### 3. Verify Impermanence

```bash
# SSH into router
ssh admin@192.168.1.1

# Check root is tmpfs
check-ephemeral

# Show what's persisted
show-persisted

# Test: Create a file in root, reboot, verify it's gone
echo "test" > /tmp/test.txt
sudo reboot

# After reboot, /tmp/test.txt should not exist
```

## What Gets Persisted

### System State (`/persist/system`)

- `/var/log` - System logs
- `/var/lib/systemd` - systemd state
- `/var/lib/nixos` - NixOS state (user IDs, etc.)
- `/var/lib/kea` - DHCP leases
- `/var/lib/unbound` - DNS cache and DNSSEC keys
- `/var/lib/fail2ban` - Banned IPs
- `/etc/ssh` - SSH host keys
- `/etc/machine-id` - Machine ID

### User Home (`/persist/home/admin`)

- `.ssh` - SSH keys and config
- `.bash_history`, `.zsh_history` - Shell history
- `.gnupg` - GPG keys
- `.cache`, `.local` - User cache and local data
- `Documents`, `Downloads` - User files

### Everything Else

**WIPED ON EVERY BOOT** - This includes:
- `/tmp`
- `/var/tmp`
- `/root`
- Anything in `/home` not explicitly persisted
- Downloaded files outside of persisted directories
- Malware or unauthorized modifications

## Adding New Persistent Directories

If you need to persist additional directories, edit `impermanence.nix`:

```nix
environment.persistence."/persist/system" = {
  directories = [
    # ... existing directories ...
    "/var/lib/new-service"  # Add new service state here
  ];

  files = [
    # ... existing files ...
    "/etc/new-config-file"  # Add new config file here
  ];
};
```

Then rebuild:

```bash
sudo nixos-rebuild switch --flake .#blue-ridge
```

## Troubleshooting

### Can't SSH After Reboot

If you lose SSH access after reboot:

1. Connect via console/monitor
2. Check if `/persist/system/etc/ssh` exists
3. Regenerate SSH host keys if needed:
   ```bash
   ssh-keygen -A
   mkdir -p /persist/system/etc/ssh
   cp -r /etc/ssh/* /persist/system/etc/ssh/
   ```

### Service Fails to Start

If a service fails because it can't write to a directory:

1. Identify the directory: `journalctl -xe`
2. Add it to `impermanence.nix` persistence list
3. Create the directory in `/persist/system`
4. Rebuild and reboot

### Lost Important Data

If you accidentally stored data outside `/persist`:

1. **Prevention**: Create a pre-reboot hook
2. **Recovery**: Not possible - data is in RAM and wiped on reboot
3. **Habit**: Always use `/persist/home/admin` for important files

### Debugging Impermanence

```bash
# Check what's in tmpfs root
ls -la /

# Check what's persisted
ls -la /persist/system
ls -la /persist/home/admin

# Verify mounts
mount | grep -E '(tmpfs|persist)'

# Check disk usage
df -h

# See tmpfiles rules
systemd-tmpfiles --cat-config
```

## Disk Space Management

### Monitoring

```bash
# Check persist usage
du -sh /persist/*

# Check Nix store usage
du -sh /nix/store

# Clean old generations
sudo nix-collect-garbage -d

# Optimize Nix store
sudo nix-store --optimize
```

### Expanding Partitions

If you need more space:

```bash
# For /persist (if you have unallocated space)
parted /dev/sda resizepart 3 100%
resize2fs /dev/disk/by-label/persist

# For /nix (more complex, requires moving /persist)
# Use GParted or similar tools
```

## Security Considerations

### Benefits

- Malware persistence is impossible (unless it modifies /persist or /nix)
- No accumulation of temporary exploits
- Clean slate on every boot
- Audit trail limited to /persist/system/var/log

### Important Notes

1. **Protect /persist**: This is the only writable persistent storage
2. **Protect /nix**: While read-only at runtime, it persists across boots
3. **Monitor /persist**: Use `du` and alerts for unusual growth
4. **Backup /persist**: This is your only persistent state
5. **Review persistence list**: Minimize what you persist

### Backup Strategy

```bash
# From your main machine, backup /persist regularly
rsync -avz --delete admin@192.168.1.1:/persist/ ./backups/blue-ridge-persist/

# Or use restic/borg for encrypted backups
```

## Advanced: Read-Only Nix Store

For maximum security, you can make `/nix` read-only:

```nix
fileSystems."/nix" = {
  device = "/dev/disk/by-label/nix";
  fsType = "ext4";
  neededForBoot = true;
  options = [ "ro" ];  # Add this
};
```

Then remount read-write only for updates:

```bash
sudo mount -o remount,rw /nix
sudo nixos-rebuild switch
sudo mount -o remount,ro /nix
```

## Summary

You now have a router with:
- ✅ Ephemeral root (tmpfs, wiped on boot)
- ✅ Persistent Nix store
- ✅ Persistent state in /persist
- ✅ Declarative configuration
- ✅ Enhanced security through impermanence

Remember: **If it's not in `/persist`, it's gone on reboot!**
