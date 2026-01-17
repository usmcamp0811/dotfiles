# Impermanence Quick Reference

## What is Impermanence?

Your router's root filesystem (`/`) is **tmpfs** - it exists only in RAM and is **wiped on every reboot**.

```
/          ← tmpfs (2GB RAM, WIPED on reboot)
/boot      ← Persistent (512MB, survives reboot)
/nix       ← Persistent (50GB, survives reboot)
/persist   ← Persistent (rest of disk, survives reboot)
```

## Golden Rule

**If it's not in `/persist` or `/nix`, it's GONE on reboot!**

## What Survives Reboots

### System State (`/persist/system`)
```
/var/log              # System logs
/var/lib/systemd      # systemd state
/var/lib/nixos        # NixOS state (UIDs, etc.)
/var/lib/kea          # DHCP leases
/var/lib/unbound      # DNS cache, DNSSEC keys
/var/lib/fail2ban     # Banned IPs
/etc/ssh              # SSH host keys
/etc/machine-id       # Machine ID
```

### User Home (`/persist/home/admin`)
```
.ssh                  # SSH keys
.bash_history         # Shell history
.zsh_history          # Shell history
.gnupg                # GPG keys
.cache                # User cache
.local                # Local data
Documents             # User documents
Downloads             # Downloads
```

### Nix Store (`/nix`)
```
/nix/store            # All packages
/nix/var              # Nix database
```

## What Gets WIPED

Everything else:
- `/tmp`
- `/var/tmp`
- `/root` (use admin account instead)
- Malware installations
- Unauthorized modifications
- Temporary files
- Downloaded files outside `/persist`

## Common Commands

### Check Status
```bash
# Verify root is tmpfs
check-ephemeral

# Show what's persisted
show-persisted

# Check disk usage
df -h
```

### Verify Impermanence
```bash
# Test: Create file, reboot, verify it's gone
echo "test" > /tmp/test-impermanence.txt
sudo reboot

# After reboot:
ls /tmp/test-impermanence.txt  # Should not exist
```

### View Persistence Config
```bash
cat /etc/nixos/config/systems/x86_64-linux/blue-ridge/impermanence.nix
```

## Adding New Persistent Data

### For System Services

Edit `impermanence.nix`:

```nix
environment.persistence."/persist/system" = {
  directories = [
    # ... existing ...
    "/var/lib/new-service"  # Add here
  ];

  files = [
    # ... existing ...
    "/etc/new-config.conf"  # Add here
  ];
};
```

### For User Data

Edit `impermanence.nix`:

```nix
environment.persistence."/persist/system" = {
  users.admin = {
    directories = [
      # ... existing ...
      "Projects"  # Relative to /home/admin
    ];

    files = [
      # ... existing ...
      ".custom-config"
    ];
  };
};
```

### Apply Changes
```bash
sudo nixos-rebuild switch --flake .#blue-ridge
```

## Troubleshooting

### Service Can't Write to Directory

**Symptom**: Service fails with "permission denied" or "no such directory"

**Solution**:
1. Find the directory it needs: `journalctl -xe`
2. Add to persistence in `impermanence.nix`
3. Create directory manually: `mkdir -p /persist/system/var/lib/service`
4. Rebuild: `sudo nixos-rebuild switch`
5. Reboot to test

### Lost Important File

**Symptom**: File existed before reboot, now gone

**Solution**:
- If it was in `/persist`: Check `/persist` directly
- If it was elsewhere: **NOT RECOVERABLE** (was in RAM)
- Prevention: Always save important files to `/persist/home/admin`

### SSH Host Keys Changed

**Symptom**: "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED"

**Cause**: `/etc/ssh` wasn't persisted or was wiped

**Solution**:
```bash
# On router
ssh-keygen -A  # Regenerate host keys
mkdir -p /persist/system/etc/ssh
cp -r /etc/ssh/* /persist/system/etc/ssh/

# On client
ssh-keygen -R 192.168.1.1  # Remove old key
```

### Disk Full on /persist

**Symptom**: Can't write to persisted directories

**Solution**:
```bash
# Check usage
du -sh /persist/*
du -sh /persist/system/*

# Common culprits
du -sh /persist/system/var/log/*  # Logs
du -sh /nix/store                  # Old generations

# Clean up
sudo nix-collect-garbage -d        # Remove old generations
sudo journalctl --vacuum-time=7d   # Keep only 7 days of logs
```

## Best Practices

### ✅ DO
- Save important files to `/persist/home/admin`
- Use declarative configuration for everything
- Add service state directories to persistence config
- Backup `/persist` regularly
- Test persistence by rebooting frequently
- Review `show-persisted` output periodically

### ❌ DON'T
- Store important data in `/tmp` or `/var/tmp`
- Rely on files in root filesystem
- Manually modify `/etc` (use NixOS config instead)
- Assume files will survive reboot unless in `/persist`
- Forget to persist service state directories

## Security Implications

### Advantages
- **Malware can't persist** (unless it modifies `/persist` or `/nix`)
- **Clean slate** on every boot
- **No accumulation** of temporary exploits
- **Forced discipline** - everything must be declared

### Attack Vectors to Monitor
- `/persist` modifications (monitor with `auditd`)
- `/nix/store` modifications (should be read-only at runtime)
- In-memory attacks (doesn't survive reboot)

### Defense in Depth
1. Monitor `/persist` for unexpected changes
2. Backup `/persist` regularly (off-site)
3. Use `nix store verify` to check integrity
4. Review persistence config regularly
5. Consider making `/nix` read-only (mount with `ro`)

## Backup Strategy

### What to Backup
- `/persist` (all of it)
- Your flake configuration (in Git)

### What NOT to Backup
- `/nix/store` (reproducible from config)
- `/` (ephemeral, wiped anyway)

### Backup Commands

```bash
# From remote machine
rsync -avz --delete admin@192.168.1.1:/persist/ ./backups/blue-ridge/

# Or use restic for encrypted backups
restic -r /backup/repo backup admin@192.168.1.1:/persist
```

## Recovery Scenarios

### Total Disk Failure
1. Replace disk
2. Reinstall NixOS (see INSTALL.md)
3. Restore `/persist` from backup
4. Deploy configuration
5. Reboot

### Corrupted /persist
1. Boot from live USB
2. Mount partitions
3. Check filesystem: `e2fsck /dev/disk/by-label/persist`
4. Restore from backup if needed

### Configuration Breaks System
1. Reboot (you'll get old root)
2. Old config still in `/nix/store`
3. Select previous generation at boot
4. Or: `nixos-rebuild switch --rollback`

## Monitoring

### Regular Checks

```bash
# Weekly checks (via cron or timer)
check-ephemeral          # Verify root is tmpfs
show-persisted           # Review what's persisted
df -h /persist           # Check disk usage
nix-store --verify       # Verify Nix store
```

### Alerts to Set Up

- `/persist` > 80% full
- Unusual files in `/persist`
- `nix-store --verify` failures
- Failed backup jobs

## Advanced: Read-Only /nix

For maximum security:

```nix
# In hardware.nix
fileSystems."/nix" = {
  device = "/dev/disk/by-label/nix";
  fsType = "ext4";
  neededForBoot = true;
  options = [ "ro" ];  # Read-only
};
```

Then for updates:
```bash
sudo mount -o remount,rw /nix
sudo nixos-rebuild switch
sudo mount -o remount,ro /nix
```

## Quick Diagnostic

If something's wrong, run this:

```bash
#!/usr/bin/env bash
echo "=== Impermanence Diagnostic ==="
echo ""
echo "Root filesystem type:"
findmnt -n -o FSTYPE /
echo ""
echo "Root usage (should be tmpfs):"
df -h /
echo ""
echo "Persist usage:"
df -h /persist
echo ""
echo "Nix usage:"
df -h /nix
echo ""
echo "Critical persisted paths exist:"
for path in /persist/system/var/lib/kea /persist/system/etc/ssh /persist/home/admin; do
  if [ -d "$path" ]; then
    echo "✓ $path"
  else
    echo "✗ $path MISSING"
  fi
done
```

## Resources

- [INSTALL.md](./INSTALL.md) - Full installation guide
- [README.md](./README.md) - General router documentation
- [nix-community/impermanence](https://github.com/nix-community/impermanence) - Upstream docs
- [Erase Your Darlings](https://grahamc.com/blog/erase-your-darlings) - Original concept
