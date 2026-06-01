# ZFS Tang/Clevis Unlock Module Changelog

## 2026-05-24 - Enhanced Error Handling and Retry Logic

### Problem
After HBA card installation (SAS9300), ZFS pools (ChestyPoolr, MotorPool) were failing to auto-unlock, resulting in password prompts during phase 2 boot via `systemd-ask-password`.

### Root Cause Analysis
The issue was **NOT** a Tang/Clevis failure, but rather a **race condition** between pool import and key loading:

1. **HBA initialization delay** - The new SAS9300 HBA takes significantly longer to enumerate drives than the previous controller
2. **Slow pool import** - Pools showed "state MISSING" for 5+ minutes, delaying import until late in boot
3. **keylocation=prompt** - After manual password entry on first boot, ZFS remembered this and set `keylocation=prompt` on all pools
4. **Systemd prompting behavior** - The `zfs-import-*.service` units check `keylocation` property and correctly prompt when set to `prompt`
5. **Bypassed initrd unlock** - Pools importing so late that they missed the initrd unlock phase entirely

Additionally:
- **SMART errors** - Interface CRC errors on drives indicated unstable storage path
- **No retry logic** - Original initrd script had no retry for transient network issues
- **Silent failures** - No diagnostic output to understand unlock status

### Complete Solution

The fix has two parts:

#### Part 1: Fix keylocation Property (One-time manual fix required)

Change `keylocation` from `prompt` to `file:///dev/null` for all pools:

```bash
sudo zfs change-key -o keylocation=file:///dev/null -l ChestyPoolr
sudo zfs change-key -o keylocation=file:///dev/null -l MotorPool
sudo zfs change-key -o keylocation=file:///dev/null -l NIXROOT
```

This prevents `zfs-import-*.service` from prompting during phase 2 boot. The file path is a placeholder that won't be used because the initrd loads keys before systemd import services run.

#### Part 2: Enhanced Initrd Script (Automatic via module update)

### Changes Made to Initrd Script

#### 1. Extended Initial Delay
- Changed from `sleep 2` to `sleep 5`
- Provides more time for network interfaces and Tang server to be fully ready

#### 2. Retry Logic for Keyfile Fetch
- Added 3 retry attempts with 3-second delays between attempts
- Added connection timeout (5s) and max timeout (10s) to curl
- Added `-f` flag to curl to fail on HTTP errors

#### 3. Comprehensive Error Handling
- Check if keyfile fetch succeeded before attempting decryption
- Check Clevis decrypt exit status
- Check if decrypted passphrase is empty
- Count successful vs failed dataset unlocks

#### 4. Diagnostic Output
- Added `[ZFS Unlock]` prefixed messages for all stages
- Shows which datasets are being unlocked
- Provides summary of successful/failed unlocks
- Clear error messages directing to manual unlock options

#### 5. Use -L prompt Flag
- Added `-L prompt` flag to `zfs load-key` command
- This overrides the dataset's `keylocation` property
- Allows piping passphrase regardless of stored keylocation value
- Critical for working with pools that have keylocation set to file paths

#### 6. Security Improvements
- Passphrase is never echoed or logged (only length/existence is checked)
- Passphrase variable is explicitly unset after use
- Encrypted keyfile variable is also unset
- Clevis stderr is captured but not displayed (could contain sensitive data)

### Behavior Changes

#### Success Path
```
[ZFS Unlock] Importing all ZFS pools...
[ZFS Unlock] Fetching encrypted keyfile from http://10.8.0.1/zfs-keyfile...
[ZFS Unlock] Keyfile retrieved successfully, decrypting with Clevis/Tang...
[ZFS Unlock] Decryption successful, loading keys into ZFS...
[ZFS Unlock] Loading key for: NIXROOT
[ZFS Unlock] Loading key for: ChestyPoolr
[ZFS Unlock] Loading key for: MotorPool
[ZFS Unlock] Summary: 3 datasets unlocked successfully, 0 failed
```

#### Failure Path - Network Issue
```
[ZFS Unlock] Importing all ZFS pools...
[ZFS Unlock] Fetching encrypted keyfile from http://10.8.0.1/zfs-keyfile...
[ZFS Unlock] Failed to fetch keyfile (attempt 1/3), retrying in 3 seconds...
[ZFS Unlock] Failed to fetch keyfile (attempt 2/3), retrying in 3 seconds...
[ZFS Unlock] Failed to fetch keyfile (attempt 3/3), retrying in 3 seconds...
[ZFS Unlock] ERROR: Failed to fetch encrypted keyfile after 3 attempts
[ZFS Unlock] Network may not be ready or Tang server may be unreachable
[ZFS Unlock] You can unlock manually via SSH or at the console prompt
```

#### Failure Path - Tang Server Unavailable
```
[ZFS Unlock] Importing all ZFS pools...
[ZFS Unlock] Fetching encrypted keyfile from http://10.8.0.1/zfs-keyfile...
[ZFS Unlock] Keyfile retrieved successfully, decrypting with Clevis/Tang...
[ZFS Unlock] ERROR: Clevis decryption failed with status 1
[ZFS Unlock] Tang server may be unavailable or keyfile may be corrupted
[ZFS Unlock] You can unlock manually via SSH or at the console prompt
```

### Testing Recommendations

1. **Test normal boot** - Verify pools unlock automatically without manual intervention
2. **Test network delay** - Simulate slow network to ensure retries work
3. **Test Tang server down** - Stop Tang server and verify graceful degradation to manual unlock
4. **Test partial unlock** - Verify summary shows correct counts for mixed success/failure

### Deployment

To deploy this update to reckless:

```bash
# From campground repository root
cd /glusterfs/shared/campground

# Build the new configuration
nix build .#nixosConfigurations.reckless.config.system.build.toplevel

# Deploy to reckless
sudo nixos-rebuild switch --flake .#reckless

# Reboot to test auto-unlock
sudo reboot
```

### Verification

After reboot, check boot logs for the new diagnostic messages:

```bash
# View initrd ZFS unlock messages
journalctl -b | grep "ZFS Unlock"

# Verify all pools are unlocked
zfs get keystatus -t filesystem,volume | grep -E "ChestyPoolr|MotorPool|NIXROOT"
```

All pools should show `keystatus = available` after successful auto-unlock.

### Backward Compatibility

This change is fully backward compatible. Existing systems will benefit from:
- Better reliability due to retry logic
- Better diagnostics when failures occur
- No configuration changes required

### Future Improvements

Potential enhancements for consideration:
1. Make retry count and delays configurable via module options
2. Add support for multiple Tang servers with failover
3. Add metrics/logging to track unlock success rates
4. Consider using systemd service for unlock instead of initrd script
