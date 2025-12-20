# Router Security Tests

Security testing and penetration testing suite for the blue-ridge router.

## Two Types of Tests

### 1. Configuration Audit (Simple)
Tests router configuration and services inside a single VM.

```bash
nix build .#checks.x86_64-linux.router-security
```

**What it checks:**
- Firewall active with DROP policy
- SSH service configuration
- fail2ban running
- Kernel hardening (IP forwarding, RP filter, SYN cookies)
- NAT masquerading configured
- Audit daemon running

### 2. Network Isolation Test (Advanced)
Spawns 5 VMs to test actual network behavior and zone isolation.

```bash
nix build .#checks.x86_64-linux.router-network-isolation
```

**Test topology:**
- Router VM (with LAN, WiFi, IoT zones)
- LAN client (192.168.1.10)
- WiFi client (192.168.10.10)
- IoT client (192.168.20.10)
- WAN "attacker" (10.0.2.100)

**What it tests:**
- ✅ WiFi → LAN works (partial isolation)
- ❌ IoT → LAN blocked (full isolation)
- ❌ IoT → WiFi blocked (full isolation)
- ❌ WAN → Router SSH blocked
- ✅ All zones can reach internet through NAT
- ✅ Firewall DROP policy enforced

### What it checks:
- ✅ SSH configuration (LAN-only, port hardening)
- ✅ fail2ban settings (max retry, ban time)
- ✅ Port forwarding analysis (dangerous ports, exposure)
- ✅ Network zone isolation policies
- ✅ Inter-zone routing rules
- ✅ DNS configuration (DNSSEC, filtering)
- ✅ LAN subnet configuration

## Runtime Penetration Tests

Runtime tests are installed on the router when you enable the pentest-tools module.

### Enable on your router:

Add to `systems/x86_64-linux/blue-ridge/default.nix`:

```nix
{
  fmf.router.pentest-tools.enable = true;
}
```

### Available tools:

1. **Internal Tests** (run on router):
   ```bash
   router-pentest-internal
   ```
   Tests:
   - Firewall active and configured
   - SSH listening on correct interface
   - IP forwarding enabled
   - Anti-spoofing (RP filter)
   - SYN flood protection
   - Network zones exist

2. **External Tests** (run from outside network):
   ```bash
   # Get your WAN IP
   curl ifconfig.me

   # Run external pentest
   router-pentest-external <WAN_IP>
   ```
   Tests:
   - SSH not exposed on WAN
   - Only expected ports open
   - No dangerous services (FTP, Telnet, SMB, RDP, etc.)
   - No unexpected UDP services
   - UPnP not exposed

3. **Zone Isolation Tests**:
   ```bash
   router-pentest-zones
   ```
   Interactive guide for manually testing zone isolation with real devices.

## Security Test Checklist

### Initial Setup
- [ ] Run config audit: `nix build .#checks.x86_64-linux.router-security`
- [ ] Fix any FAILED checks
- [ ] Review WARNINGS
- [ ] Enable pentest-tools on router

### Regular Testing (Monthly)
- [ ] Run internal tests on router
- [ ] Run external tests from outside network
- [ ] Test zone isolation with devices
- [ ] Review fail2ban logs
- [ ] Check for unexpected connections: `netstat -tn`

### After Configuration Changes
- [ ] Run config audit
- [ ] Re-run internal tests
- [ ] Re-test affected zones

## Example Test Session

```bash
# On your development machine
cd /config
nix build .#checks.x86_64-linux.router-security
cat result/security-audit.log

# SSH into router
ssh admin@192.169.1.1

# Run internal tests
router-pentest-internal

# From external machine (phone hotspot, VPS, etc.)
router-pentest-external $(curl -s ifconfig.me)
```

## Common Issues

### SSH exposed on WAN
**Symptom:** External test shows SSH port 22 open
**Fix:** Ensure `services.openssh.settings.ListenAddress` is set to LAN IP only

### Port forwards to dangerous services
**Symptom:** Config audit fails on port 22/23/3389 forwards
**Fix:** Remove the forward or use VPN instead

### Zones not isolated
**Symptom:** Can ping between IoT and LAN zones
**Fix:** Check `isolation = "full"` in zone config and verify no interZoneRoutes allow it

### fail2ban not running
**Symptom:** Internal test shows fail2ban inactive
**Fix:** `systemctl start fail2ban` and check `journalctl -u fail2ban`

## Integration with CI/CD

Add to your deployment workflow:

```bash
# Pre-deployment security audit
nix build .#checks.x86_64-linux.router-security || exit 1

# Post-deployment verification
ssh admin@router 'router-pentest-internal' || exit 1
```

## Advanced Testing

### Packet Capture
```bash
# Capture traffic on WAN interface
tcpdump -i enp1s0 -w /tmp/wan-capture.pcap

# Analyze with tshark
tshark -r /tmp/wan-capture.pcap
```

### Port Scanning (from router)
```bash
# Scan your own WAN IP from router
nmap -p 1-65535 $(curl -s ifconfig.me)
```

### Zone Traffic Analysis
```bash
# Watch traffic between zones
tcpdump -i br-lan.10 icmp -v
```
