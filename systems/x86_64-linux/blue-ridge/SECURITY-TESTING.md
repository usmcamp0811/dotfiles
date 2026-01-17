# Blue Ridge Router Security Testing

This document describes how to test the security of your blue-ridge router.

## Available Security Tests

### 1. Automated NixOS Test Suite

The comprehensive automated security test that runs in a VM.

**What it tests:**
- ✅ No services exposed on WAN
- ✅ SSH only accessible from LAN
- ✅ Firewall properly configured with default deny
- ✅ DNS not acting as open resolver
- ✅ DHCP only on LAN
- ✅ No UPnP or SNMP exposed
- ✅ No default credentials work
- ✅ Root login disabled
- ✅ Kernel hardening enabled
- ✅ fail2ban protecting SSH
- ✅ IPv6 disabled (as configured)
- ✅ Impermanence active
- ✅ Helper scripts available
- ✅ No accidental port forwarding
- ✅ Proper file permissions

**Run the test:**

```bash
# Run the comprehensive security test
nix build .#checks.x86_64-linux.router-security -L

# Or if using flake commands
nix flake check --print-build-logs
```

The test creates a virtual network with:
- Router under test
- Simulated WAN client (attacker)
- Simulated LAN client (trusted user)

It performs automated pentesting from both perspectives.

### 2. Standalone Penetration Testing Script

A portable script you can run against a live router.

**Install the script:**

```bash
nix profile install .#router-pentest

# Or run directly
nix run .#router-pentest
```

**Test from LAN:**

```bash
# Basic LAN test
router-pentest --from lan

# Specify custom LAN IP
router-pentest --lan-ip 192.168.1.1 --from lan
```

**Test from WAN (external):**

```bash
# Test from WAN perspective
router-pentest --wan-ip YOUR.WAN.IP --from wan

# Or set environment variable
export ROUTER_WAN_IP=203.0.113.10
router-pentest --from wan
```

**What it checks:**

From LAN:
- SSH is accessible
- DNS responds
- No default credentials
- SSH uses modern protocols
- No unnecessary services

From WAN:
- SSH is blocked
- DNS doesn't respond (not an open resolver)
- No web interfaces exposed
- No UPnP or SNMP
- Comprehensive port scan
- No open ports

## Manual Security Testing

### Basic Port Scan

```bash
# From LAN
nmap -p- -T4 192.168.1.1

# From WAN (if you have external access)
nmap -p- -T4 YOUR.WAN.IP
```

### SSH Security Test

```bash
# From LAN - should connect (with key)
ssh admin@192.168.1.1

# Test SSH version
ssh -v admin@192.168.1.1 2>&1 | grep "remote software version"

# Try password auth (should fail)
ssh -o PreferredAuthentications=password admin@192.168.1.1
```

### DNS Security Test

```bash
# From LAN - should work
dig @192.168.1.1 google.com

# From WAN - should NOT work (test from external machine)
dig @YOUR.WAN.IP google.com
```

### Firewall Rule Verification

```bash
# SSH to router and check nftables rules
ssh admin@192.168.1.1

# View all firewall rules
sudo nft list ruleset

# Check input chain policy (should be drop)
sudo nft list chain inet filter input

# Check forward chain
sudo nft list chain inet filter forward

# Check NAT rules
sudo nft list table inet nat
```

### Kernel Hardening Verification

```bash
# SSH to router
ssh admin@192.168.1.1

# Check security settings
sysctl net.ipv4.conf.all.rp_filter         # Should be 1
sysctl net.ipv4.conf.all.accept_redirects  # Should be 0
sysctl net.ipv4.conf.all.send_redirects    # Should be 0
sysctl net.ipv4.tcp_syncookies             # Should be 1
sysctl kernel.dmesg_restrict               # Should be 1
sysctl kernel.kptr_restrict                # Should be 2
```

### Service Enumeration

```bash
# Check what's listening
ssh admin@192.168.1.1 sudo ss -tlnp

# Should see:
# - SSH on 192.168.1.1:22 (LAN only)
# - DNS on 192.168.1.1:53 (LAN only)
# - DHCP on 0.0.0.0:67 (broadcast)

# Should NOT see anything on 0.0.0.0:* that's accessible from WAN
```

### fail2ban Status

```bash
ssh admin@192.168.1.1

# Check fail2ban status
sudo fail2ban-client status

# Check SSH jail
sudo fail2ban-client status sshd

# View banned IPs
sudo fail2ban-client get sshd banip
```

### Impermanence Verification

```bash
ssh admin@192.168.1.1

# Check root is tmpfs
mount | grep "on / type tmpfs"

# Verify ephemeral
check-ephemeral

# Show what's persisted
show-persisted

# Test: Create file, reboot, verify it's gone
echo "test" > /tmp/security-test.txt
sudo reboot

# After reboot:
ls /tmp/security-test.txt  # Should not exist
```

## Security Checklist

### Pre-Deployment

- [ ] Change default SSH port (optional)
- [ ] Add SSH public key
- [ ] Set strong admin password hash
- [ ] Review firewall rules
- [ ] Run automated security tests
- [ ] Verify interface names

### Post-Deployment

- [ ] Test SSH from LAN (should work)
- [ ] Test SSH from WAN (should fail)
- [ ] Test DNS from LAN (should work)
- [ ] Test DNS from WAN (should fail)
- [ ] Run port scan from WAN (should show no open ports)
- [ ] Check fail2ban is active
- [ ] Verify impermanence (reboot test)
- [ ] Review logs for anomalies
- [ ] Test NAT is working for LAN clients

### Ongoing Maintenance

- [ ] Weekly: Check fail2ban logs
- [ ] Weekly: Review /var/log/auth.log
- [ ] Monthly: Run security tests
- [ ] Monthly: Update system
- [ ] Quarterly: Full security audit
- [ ] Backup /persist regularly

## Common Security Issues

### Issue: SSH accessible from WAN

**Check:**
```bash
# From external network
ssh admin@YOUR.WAN.IP
```

**Fix:**
Ensure SSH is only listening on LAN IP. Check `router/security/default.nix`:
```nix
services.openssh.settings.ListenAddress = routerCfg.lan.gateway;
```

### Issue: DNS acting as open resolver

**Check:**
```bash
# From external network
dig @YOUR.WAN.IP google.com +short
```

**Fix:**
Ensure Unbound only listens on LAN. Check `router/core/default.nix`:
```nix
services.unbound.settings.server.interface = ["127.0.0.1" "::1" cfg.lan.gateway];
```

### Issue: Port forwarding misconfiguration

**Check:**
```bash
ssh admin@192.168.1.1 sudo nft list table inet nat
```

**Fix:**
Review `firewall.extraRules` in your config and ensure DNAT rules are intentional.

### Issue: Weak SSH configuration

**Check:**
```bash
ssh -v admin@192.168.1.1 2>&1 | grep -E "kex|cipher|mac"
```

**Fix:**
Modern ciphers are enforced in `router/security/default.nix`. Verify the configuration is active.

## Advanced Testing

### Metasploit Framework

For advanced security testing:

```bash
# Install Metasploit
nix-shell -p metasploit

# Start msfconsole
msfconsole

# Search for router exploits
msf6 > search type:exploit platform:linux router

# Try router exploitation modules
msf6 > use auxiliary/scanner/ssh/ssh_version
msf6 > set RHOSTS YOUR.WAN.IP
msf6 > run
```

### Nikto Web Scanner

```bash
# Test for web vulnerabilities (should find nothing)
nix-shell -p nikto
nikto -h http://YOUR.WAN.IP
nikto -h https://YOUR.WAN.IP
```

### OpenVAS Vulnerability Scanner

For comprehensive vulnerability scanning:

```bash
# This requires more setup, see OpenVAS documentation
# Should show minimal to no vulnerabilities
```

## Compliance

### CIS Benchmark

The router configuration addresses many CIS Benchmark requirements:

- ✅ Disable unused network protocols
- ✅ Ensure packet redirect sending is disabled
- ✅ Ensure source routed packets are not accepted
- ✅ Ensure ICMP redirects are not accepted
- ✅ Ensure suspicious packets are logged
- ✅ Ensure TCP SYN Cookies is enabled
- ✅ Ensure IPv6 router advertisements are not accepted

### NIST Guidelines

Follows NIST recommendations for:
- Network segmentation (WAN/LAN separation)
- Principle of least privilege (minimal services)
- Defense in depth (multiple security layers)
- Secure configuration management (declarative config)

## Reporting Security Issues

If you discover a security vulnerability in the router configuration:

1. **DO NOT** open a public issue
2. Document the vulnerability
3. Test if it's reproducible
4. Create a private security advisory
5. Include steps to reproduce
6. Suggest a fix if possible

## Resources

- [NixOS Security](https://nixos.org/manual/nixos/stable/#sec-security)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [OWASP IoT Security](https://owasp.org/www-project-internet-of-things/)
- [Router Security Best Practices](https://www.cisa.gov/uscert/ncas/tips/ST15-002)

## Quick Reference

```bash
# Run automated tests
nix build .#checks.x86_64-linux.router-security -L

# Run pentest from LAN
nix run .#router-pentest -- --from lan

# Run pentest from WAN
nix run .#router-pentest -- --wan-ip YOUR.IP --from wan

# Check router security status
ssh admin@192.168.1.1 router-security-check

# View firewall rules
ssh admin@192.168.1.1 sudo nft list ruleset

# Check fail2ban
ssh admin@192.168.1.1 sudo fail2ban-client status

# Verify impermanence
ssh admin@192.168.1.1 check-ephemeral
```
