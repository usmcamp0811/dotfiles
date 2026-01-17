# Encryption Options for Blue Ridge Router

This guide compares different encryption approaches for a router that requires unattended boot.

## The Dilemma

**Conflicting Requirements:**
- **Security**: Want encryption to protect secrets if router is stolen
- **Availability**: Need router to auto-boot after power outage (no manual password entry)

**Key Insight**: Unattended boot + encryption = key must be stored somewhere accessible during boot

## Threat Model

Before choosing encryption, consider your threats:

### What Are You Protecting Against?

1. **Physical theft of powered-off device**
   - Attacker steals router and extracts disk
   - Reads data offline

2. **Physical theft of running device**
   - Cold boot attacks (RAM extraction)
   - Data already decrypted in memory

3. **Remote network attacks**
   - Encryption doesn't help (system is running)
   - Network security matters more

4. **Evil maid attacks**
   - Physical access while you're away
   - Can modify bootloader, install keylogger

### Where Is Your Router?

- **Home/Office**: High physical security, trusted location
- **Colo/Data Center**: Medium security, shared physical space
- **Remote Site**: Low security, may be accessible to others

## Encryption Options

### Option 1: No Encryption (Rely on Physical Security + Impermanence)

**Config:** `disko.nix` (original)

**Pros:**
- ✅ Simplest setup
- ✅ Always auto-boots
- ✅ No key management
- ✅ Impermanence protects ephemeral root

**Cons:**
- ❌ Physical theft = all data readable
- ❌ SSH keys, configs, logs in cleartext on disk

**Use When:**
- Router is in physically secure location (locked room, home)
- Physical access = already compromised (they can just plug in USB)
- Prioritize availability over data-at-rest security

**Threat Protection:**
- ✅ Ephemeral malware (wiped on reboot)
- ❌ Physical theft
- ❌ Offline disk analysis

---

### Option 2: Encrypted /persist Only (RECOMMENDED)

**Config:** `disko-encrypted.nix`

**Pros:**
- ✅ Protects actual secrets (SSH keys, configs, logs)
- ✅ Auto-boots with key file
- ✅ /nix unencrypted (contains no secrets anyway)
- ✅ Balanced security/availability

**Cons:**
- ❌ Key file on /boot (physical access = can retrieve key)
- ❌ /nix readable (but contains only world-readable packages)

**Use When:**
- Need to protect configs/keys from offline disk reading
- Have moderate physical security
- Want unattended boot
- Understand that nix store is inherently public

**Threat Protection:**
- ✅ Offline reading of secrets in /persist
- ✅ Ephemeral root protection
- ❌ Physical access to /boot (key file accessible)
- ❌ Evil maid attacks

**What's Protected:**
- SSH host keys (`/persist/system/etc/ssh`)
- User SSH keys (`/persist/home/admin/.ssh`)
- Network configs and DHCP leases
- Logs (`/persist/system/var/log`)
- fail2ban state

**What's NOT Protected:**
- /nix store (packages are public anyway)
- /boot (needs to be readable to boot)

---

### Option 3: Full Disk Encryption (Maximum Security)

**Config:** `disko-full-encryption.nix`

**Pros:**
- ✅ Everything encrypted (except /boot)
- ✅ Maximum data-at-rest protection
- ✅ Still auto-boots with key file

**Cons:**
- ❌ Key file still on /boot (same compromise as Option 2)
- ❌ More complex setup
- ❌ Encrypting /nix is security theater (no secrets there)
- ❌ Slightly slower boot/runtime

**Use When:**
- Policy/compliance requires full disk encryption
- Want to encrypt swap (may contain sensitive data)
- Don't mind the complexity

**Threat Protection:**
- ✅ Same as Option 2 (key file still accessible)
- ❌ Minimal benefit over Option 2 for router use case

---

### Option 4: TPM-Based Encryption (Advanced)

**Not yet implemented** - Would require custom setup

**Pros:**
- ✅ Key sealed in TPM, not on disk
- ✅ Auto-boot if system unmodified
- ✅ Detects bootloader tampering

**Cons:**
- ❌ Complex setup (requires TPM 2.0)
- ❌ Recovery harder if TPM fails
- ❌ Motherboard replacement = lost data
- ❌ May not work on all Intel N100 devices

**Use When:**
- Router has TPM 2.0
- Need protection against evil maid attacks
- Have good backup/recovery procedures

---

## Recommendation for Blue Ridge

### For Home/Trusted Location: Option 2 (Encrypted /persist)

Use `disko-encrypted.nix`:

```bash
sudo nix run github:nix-community/disko -- \
  --mode disko \
  /tmp/config/systems/x86_64-linux/blue-ridge/disko-encrypted.nix
```

**Why:**
1. Your secrets (SSH keys, configs) are encrypted
2. Router auto-boots after power outage
3. /nix doesn't need encryption (no secrets)
4. Balanced security vs. availability

**Physical Security Requirements:**
- Keep router in locked room/cabinet
- /boot contains encryption key (protect physical access)
- Consider Secure Boot (prevents /boot tampering)

### For High-Security Environment: Option 4 (TPM) or Manual Unlock

If you need true protection against physical theft, you must:

1. **TPM-based encryption** (key never on disk)
2. **Network unlock** (Tang/Clevis - unlock over network)
3. **Accept manual unlock** (not unattended)

There is **no way** to have both unattended boot AND protection against physical theft without TPM/network unlock.

## Installation Steps (Encrypted /persist)

### 1. Generate Encryption Key

```bash
# On installer, generate random key
dd if=/dev/random of=/tmp/persist.key bs=1024 count=4
chmod 600 /tmp/persist.key

# IMPORTANT: Back this up! If lost, /persist data is unrecoverable
cp /tmp/persist.key /path/to/safe/backup/
```

### 2. Run Disko

```bash
# Use encrypted config
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko \
  /tmp/config/systems/x86_64-linux/blue-ridge/disko-encrypted.nix
```

Disko will:
- Partition disk
- Create LUKS container for /persist using key file
- Format and mount everything

### 3. Copy Key to /boot

```bash
# After disko mounts everything, copy key to boot
cp /tmp/persist.key /mnt/boot/persist.key
chmod 600 /mnt/boot/persist.key
```

### 4. Update hardware.nix

You'll need to reference the LUKS device:

```nix
# Add to hardware.nix
boot.initrd.luks.devices."crypted-persist" = {
  device = "/dev/disk/by-uuid/YOUR-PARTITION-UUID";
  keyFile = "/boot/persist.key";
  allowDiscards = true;
};
```

Get UUID with: `lsblk -f`

### 5. Install NixOS

```bash
mkdir -p /mnt/persist/system
mkdir -p /mnt/persist/home/admin

sudo nixos-install --flake /tmp/config#blue-ridge
```

### 6. Secure /boot

After installation, protect /boot:

```bash
# On running system, make /boot read-only after updates
# Add to hardware.nix:
fileSystems."/boot".options = [ "umask=0077" "ro" ];

# Remount rw only for updates:
sudo mount -o remount,rw /boot
sudo nixos-rebuild switch
sudo mount -o remount,ro /boot
```

## Additional Hardening

### Enable Secure Boot (Prevents /boot Tampering)

With Secure Boot, attacker can't easily modify bootloader to steal key:

```nix
# Add to configuration.nix
boot.loader.systemd-boot.enable = true;
boot.lanzaboote.enable = true;  # Secure Boot for systemd-boot
```

Requires signing boot components with your keys.

### Monitor /boot Integrity

```nix
# Add AIDE or similar for file integrity monitoring
services.aide = {
  enable = true;
  settings = ''
    /boot R+sha256
  '';
};
```

### Regular Key Rotation

Periodically change LUKS key:

```bash
# Add new key
cryptsetup luksAddKey /dev/sda4 /boot/persist-new.key

# Update config to use new key
# Remove old key
cryptsetup luksRemoveKey /dev/sda4 /boot/persist.key
```

## Backup Strategy

**CRITICAL**: Backup your encryption keys!

```bash
# From running system
scp /boot/persist.key you@safe-location:backups/blue-ridge/

# Or backup entire /boot
rsync -av /boot/ you@safe-location:backups/blue-ridge-boot/
```

**Recovery without key = complete data loss**

## Comparison Matrix

| Feature | No Encryption | Encrypted /persist | Full Encryption | TPM-based |
|---------|---------------|-------------------|----------------|-----------|
| Auto-boot | ✅ | ✅ | ✅ | ✅ |
| Protects secrets | ❌ | ✅ | ✅ | ✅ |
| Physical theft protection | ❌ | ⚠️  Partial | ⚠️  Partial | ✅ |
| Evil maid protection | ❌ | ❌ | ❌ | ✅ |
| Complexity | Low | Medium | High | Very High |
| Performance impact | None | Minimal | Low | Minimal |
| Recovery difficulty | Easy | Medium | Medium | Hard |

⚠️  = Protected only if attacker doesn't get /boot

## Final Recommendation

**For Blue Ridge in a home/office environment:**

Use **Option 2: Encrypted /persist** (`disko-encrypted.nix`)

**Plus:**
- Physical security (locked location)
- Secure Boot (prevents /boot tampering)
- Read-only /boot mount (remount rw only for updates)
- Regular backups of /boot/persist.key
- File integrity monitoring on /boot

This provides:
- ✅ Unattended boot
- ✅ Protection of SSH keys and configs
- ✅ Impermanence benefits (ephemeral root)
- ✅ Practical security without excessive complexity

**Accept:**
- Physical access to powered-off router = potential key extraction from /boot
- Mitigated by physical security + Secure Boot

For truly unattended boot, this is the best balance of security and availability.
