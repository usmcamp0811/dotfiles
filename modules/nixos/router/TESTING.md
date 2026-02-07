# Router Module Testing Guide

Comprehensive testing procedures for the Campground router modules.

## Table of Contents

- [Testing Overview](#testing-overview)
- [Pre-Deployment Testing](#pre-deployment-testing)
- [Basic Router Tests](#basic-router-tests)
- [Zone Isolation Tests](#zone-isolation-tests)
- [Security Tests](#security-tests)
- [Port Forwarding Tests](#port-forwarding-tests)
- [DNS and DHCP Tests](#dns-and-dhcp-tests)
- [Performance Tests](#performance-tests)
- [Automated Testing](#automated-testing)
- [Troubleshooting Tests](#troubleshooting-tests)

---

## Testing Overview

### Test Environments

1. **VM Testing** - Safe testing in virtualized environment
2. **Lab Testing** - Testing on real hardware in isolated network
3. **Production Testing** - Final verification before deployment

### Testing Principles

- **Test incrementally**: Test each module as you enable it
- **Isolate changes**: Test one change at a time
- **Document results**: Record test results for comparison
- **Automate when possible**: Use scripts for repeatable tests

### Required Tools

Install these tools for testing:

```bash
# On your test machine
nix-shell -p nmap dig netcat tcpdump curl iperf3 wireguard-tools

# On the router
# Most tools are installed via security module
```

---

## Pre-Deployment Testing

### 1. Configuration Validation

Test your configuration builds before deployment:

```bash
# Build the configuration (don't activate)
nixos-rebuild build --flake .#router

# Check for errors
echo $?  # Should be 0

# Preview activation script
nixos-rebuild build --flake .#router
./result/bin/switch-to-configuration test
```

### 2. VM Testing

Test in a VM before deploying to real hardware:

```bash
# Build VM
nixos-rebuild build-vm --flake .#router

# Run VM
./result/bin/run-router-vm

# Test inside VM
# ... perform tests ...

# Exit VM
# No changes persist, safe testing
```

### 3. Dry-Run Activation

Activate configuration without making it permanent:

```bash
# Test activation (reverts on reboot)
nixos-rebuild test --flake .#router

# If it works:
nixos-rebuild switch --flake .#router
```

---

## Basic Router Tests

### Test 1: Network Interfaces

Verify all network interfaces are up and configured correctly.

```bash
# List all interfaces
ip link show

# Expected output:
# - enp1s0 (WAN)
# - br-lan (LAN bridge)
# - enp2s0, enp3s0, enp4s0 (enslaved to br-lan)
# - br-lan.10, br-lan.20, br-lan.30 (VLAN interfaces, if zones enabled)

# Check IP addresses
ip addr show

# Expected:
# br-lan: 192.169.1.1/24
# br-lan.10: 192.169.10.1/24
# br-lan.20: 192.169.20.1/24
# br-lan.30: 192.169.30.1/24
```

**Pass Criteria:**
- ✅ All physical interfaces are UP
- ✅ br-lan has correct IP address
- ✅ All VLAN interfaces exist (if zones enabled)
- ✅ All VLAN interfaces have correct IP addresses

### Test 2: Routing and Forwarding

Verify IP forwarding and routing table.

```bash
# Check IP forwarding is enabled
cat /proc/sys/net/ipv4/ip_forward
# Expected: 1

# Check routing table
ip route show

# Expected:
# - Default route via WAN
# - Routes for each zone subnet
```

**Pass Criteria:**
- ✅ IP forwarding is enabled
- ✅ Default route points to WAN
- ✅ LAN/zone routes are present

### Test 3: NAT and Masquerading

Verify NAT is working.

```bash
# Check nftables NAT rules
nft list table ip nat

# Expected output should include:
# chain postrouting {
#   oifname "enp1s0" masquerade
# }
```

**Pass Criteria:**
- ✅ NAT table exists
- ✅ Masquerade rule for WAN interface is present

### Test 4: Basic Connectivity

Test internet connectivity from router and clients.

```bash
# From router
ping -c 4 1.1.1.1
ping -c 4 google.com

# From LAN client
ping -c 4 192.169.1.1  # Router gateway
ping -c 4 1.1.1.1       # Internet
ping -c 4 google.com    # DNS + Internet
```

**Pass Criteria:**
- ✅ Router can ping internet
- ✅ Router can resolve DNS
- ✅ LAN client can ping router
- ✅ LAN client can ping internet
- ✅ LAN client can resolve DNS

### Test 5: Firewall Basic Rules

Verify firewall is active and blocking by default.

```bash
# Check nftables is running
systemctl status nftables

# List firewall rules
nft list ruleset

# Verify default policy is DROP
nft list chain inet filter input
# Should show: policy drop

nft list chain inet filter forward
# Should show: policy drop
```

**Pass Criteria:**
- ✅ nftables service is active
- ✅ Default policy is DROP for input and forward chains
- ✅ Established/related connections are allowed

---

## Zone Isolation Tests

### Test 6: Zone to Zone Isolation

Verify zones are properly isolated from each other.

**Setup:**
- Device A in WiFi zone (192.169.10.x)
- Device B in IoT zone (192.169.20.x)
- Device C in Guest zone (192.169.30.x)
- Device D in LAN zone (192.169.1.x)

**Test Cases:**

```bash
# From WiFi device (192.169.10.x)
ping 192.169.1.1      # Router gateway - SHOULD WORK
ping 192.169.1.100    # LAN device - CHECK INTER-ZONE RULES
ping 192.169.20.100   # IoT device - SHOULD FAIL (unless route exists)
ping 192.169.30.100   # Guest device - SHOULD FAIL

# From IoT device (192.169.20.x)
ping 192.169.1.1      # Router gateway - SHOULD WORK
ping 192.169.1.100    # LAN device - SHOULD FAIL (unless route exists)
ping 192.169.10.100   # WiFi device - SHOULD FAIL
ping 192.169.30.100   # Guest device - SHOULD FAIL

# From Guest device (192.169.30.x)
ping 192.169.1.1      # Router gateway - SHOULD WORK
ping 192.169.1.100    # LAN device - SHOULD FAIL (unless route exists)
ping 192.169.10.100   # WiFi device - SHOULD FAIL
ping 192.169.20.100   # IoT device - SHOULD FAIL

# From LAN device (192.169.1.x)
ping 192.169.10.100   # WiFi device - CHECK ISOLATION LEVEL
ping 192.169.20.100   # IoT device - CHECK ISOLATION LEVEL
ping 192.169.30.100   # Guest device - CHECK ISOLATION LEVEL
```

**Pass Criteria (Full Isolation):**
- ✅ Zones cannot ping each other (except via explicit routes)
- ✅ All zones can ping their gateway
- ✅ All zones can ping internet (if `allowInternet = true`)

### Test 7: Inter-Zone Routes

Verify explicit inter-zone routes work correctly.

**Example Route:**
```nix
{
  from = "iot";
  to = ["lan"];
  protocol = "tcp";
  ports = [8123];
  destinationIPs = ["192.169.1.100"];
  description = "IoT to Home Assistant";
}
```

**Test:**
```bash
# From IoT device (192.169.20.x)
curl http://192.169.1.100:8123    # SHOULD WORK
curl http://192.169.1.100:80      # SHOULD FAIL (port not allowed)
curl http://192.169.1.101:8123    # SHOULD FAIL (IP not allowed)

# Verify firewall rule exists
nft list table inet zones | grep 8123
```

**Pass Criteria:**
- ✅ Allowed protocol/port/IP works
- ✅ Non-allowed protocol/port/IP fails
- ✅ Firewall rule is present in nftables

### Test 8: Zone Internet Access

Verify zones can or cannot access internet based on `allowInternet` setting.

```bash
# From each zone, test internet access
ping -c 4 1.1.1.1
curl -I https://example.com

# Check firewall rules
nft list table inet zones | grep -A 5 "Zone -> WAN"
```

**Pass Criteria:**
- ✅ Zones with `allowInternet = true` can reach internet
- ✅ Zones with `allowInternet = false` cannot reach internet

---

## Security Tests

### Test 9: SSH Access

Verify SSH is LAN-only and properly secured.

```bash
# From LAN client
ssh user@192.169.1.1  # SHOULD WORK

# From internet (WAN)
ssh user@<WAN_IP>     # SHOULD FAIL (connection refused/timeout)

# Verify SSH is listening on LAN IP only
netstat -tlnp | grep :22
# Should show: 192.169.1.1:22 (not 0.0.0.0:22)

# Check SSH config
cat /etc/ssh/sshd_config | grep ListenAddress
# Should show: ListenAddress 192.169.1.1
```

**Pass Criteria:**
- ✅ SSH accessible from LAN
- ✅ SSH not accessible from WAN
- ✅ SSH listening on LAN IP only

### Test 10: fail2ban

Verify fail2ban is protecting SSH.

```bash
# Check fail2ban status
systemctl status fail2ban

# View SSH jail status
fail2ban-client status sshd

# Simulate brute force (from LAN client)
# Try wrong password 4 times
ssh wronguser@192.169.1.1
# ... repeat 3 more times

# Check if IP is banned
fail2ban-client status sshd
# Should show your IP in banned list

# Check nftables for ban
nft list ruleset | grep <your-IP>
```

**Pass Criteria:**
- ✅ fail2ban service is running
- ✅ SSH jail is active
- ✅ Brute force attempts result in ban
- ✅ Banned IP appears in nftables

### Test 11: WAN Exposure

Verify no unexpected services are exposed to WAN.

```bash
# From external network, scan WAN IP
nmap -Pn -p 1-65535 <WAN_IP>

# Expected: Only port forwards should be open
# SSH (22), HTTP (80), HTTPS (443), etc. should be CLOSED
# Unless explicitly configured in portForwards
```

**Pass Criteria:**
- ✅ No unexpected open ports on WAN
- ✅ Only configured port forwards are accessible

### Test 12: Kernel Hardening

Verify kernel security parameters are set.

```bash
# Check sysctl settings
sysctl kernel.kptr_restrict       # Expected: 2
sysctl kernel.dmesg_restrict      # Expected: 1
sysctl kernel.unprivileged_bpf_disabled  # Expected: 1
sysctl net.ipv4.tcp_syncookies    # Expected: 1
sysctl net.ipv4.conf.all.rp_filter  # Expected: 1
```

**Pass Criteria:**
- ✅ All security parameters are set correctly

### Test 13: Security Audit

Run the built-in security check script.

```bash
# On router
router-security-check

# Review output:
# - Firewall status
# - SSH status
# - Active connections
# - Recent SSH attempts
# - fail2ban status
```

**Pass Criteria:**
- ✅ All services show as active
- ✅ No suspicious SSH attempts
- ✅ No unexpected active connections

---

## Port Forwarding Tests

### Test 14: Port Forward Functionality

Verify port forwards work correctly.

**Example Port Forward:**
```nix
{
  port = 443;
  destination = "192.169.1.100";
  protocol = "tcp";
  description = "HTTPS to web server";
}
```

**Test:**
```bash
# From external network
curl -I https://<WAN_IP>:443

# Should receive response from 192.169.1.100

# Verify NAT rule
nft list table ip nat | grep 443
# Expected: dnat to 192.169.1.100:443

# Verify filter rule
nft list table inet filter | grep 443
# Expected: allow forward to 192.169.1.100:443
```

**Pass Criteria:**
- ✅ External connection reaches internal server
- ✅ NAT DNAT rule exists
- ✅ Firewall forward rule exists

### Test 15: Port Forward with Different Destination Port

**Example:**
```nix
{
  port = 2222;
  destination = "192.169.1.10";
  destinationPort = 22;
  protocol = "tcp";
  description = "SSH to dev server";
}
```

**Test:**
```bash
# From external network
ssh -p 2222 user@<WAN_IP>

# Should connect to 192.169.1.10:22

# Verify NAT rule
nft list table ip nat | grep 2222
# Expected: dnat to 192.169.1.10:22
```

**Pass Criteria:**
- ✅ Connection to WAN:2222 reaches 192.169.1.10:22
- ✅ NAT rule shows correct port translation

---

## DNS and DHCP Tests

### Test 16: DHCP Lease Assignment

Verify DHCP server assigns leases correctly.

```bash
# On router, check dnsmasq status
systemctl status dnsmasq

# View DHCP leases
cat /var/lib/dnsmasq/dnsmasq.leases

# From client, request DHCP lease
dhclient -r  # Release current lease
dhclient     # Request new lease

# Check client received correct IP and DNS
ip addr show
cat /etc/resolv.conf
```

**Pass Criteria:**
- ✅ dnsmasq service is running
- ✅ Client receives IP in configured range
- ✅ Client receives correct gateway
- ✅ Client receives correct DNS server

### Test 17: Static DHCP Leases

Verify static leases work correctly.

**Example Static Lease:**
```nix
{
  mac = "aa:bb:cc:dd:ee:ff";
  ip = "192.169.20.100";
  hostname = "thermostat";
}
```

**Test:**
```bash
# Check dnsmasq config includes static lease
cat /etc/dnsmasq.conf | grep "aa:bb:cc:dd:ee:ff"
# Expected: dhcp-host=aa:bb:cc:dd:ee:ff,192.169.20.100,thermostat

# From device with MAC aa:bb:cc:dd:ee:ff
dhclient -r && dhclient

# Check received IP
ip addr show
# Expected: 192.169.20.100

# Check hostname resolution
ping thermostat  # Should resolve to 192.169.20.100
```

**Pass Criteria:**
- ✅ dnsmasq config has static lease entry
- ✅ Device receives assigned IP
- ✅ Hostname resolves correctly

### Test 18: DNS Resolution

Verify DNS resolver works correctly.

```bash
# From LAN client
dig @192.169.1.1 google.com
nslookup google.com 192.169.1.1

# Check DNSSEC validation (if enabled)
dig @192.169.1.1 dnssec-deployment.org
# Should succeed (valid DNSSEC)

dig @192.169.1.1 dnssec-failed.org
# Should fail (invalid DNSSEC)

# Check dnsmasq is forwarding
journalctl -u dnsmasq -f
# Make some DNS queries and watch logs
```

**Pass Criteria:**
- ✅ DNS queries are resolved
- ✅ DNSSEC validation works (if enabled)
- ✅ dnsmasq forwards to configured upstream DNS

### Test 19: Per-Zone DNS

Verify zones use correct DNS servers.

**Example:**
```nix
guest.dns.servers = ["1.1.1.3" "1.0.0.3"];  # Cloudflare malware blocking
```

**Test:**
```bash
# From guest zone client
cat /etc/resolv.conf
# Expected: nameserver 1.1.1.3 and 1.0.0.3

# Test DNS resolution
dig @1.1.1.3 example.com

# Check DHCP advertises correct DNS
# On router
cat /etc/dnsmasq.conf | grep "tag:br-lan.30"
# Expected: option:dns-server,1.1.1.3,1.0.0.3
```

**Pass Criteria:**
- ✅ Guest clients receive correct DNS servers via DHCP
- ✅ DNS queries go to configured servers

---

## Performance Tests

### Test 20: Throughput Test

Measure router throughput.

```bash
# Install iperf3 on router and client
nix-shell -p iperf3

# On router
iperf3 -s

# On LAN client
iperf3 -c 192.169.1.1

# Expected: Near line speed (1 Gbps for gigabit ethernet)

# Test WAN throughput (if possible)
# On external server
iperf3 -s

# On LAN client
iperf3 -c <external-server>
```

**Pass Criteria:**
- ✅ LAN throughput > 900 Mbps (for gigabit)
- ✅ WAN throughput matches ISP speed

### Test 21: Latency Test

Measure router latency.

```bash
# From LAN client to router
ping -c 100 192.169.1.1

# Calculate average, min, max
# Expected: < 1ms for LAN

# To internet
ping -c 100 1.1.1.1

# Expected: Similar to pinging directly from router
```

**Pass Criteria:**
- ✅ LAN latency < 1ms
- ✅ WAN latency similar to baseline (router adds minimal overhead)

### Test 22: Connection Tracking

Verify connection tracking works and handles load.

```bash
# Check conntrack status
conntrack -L

# Count active connections
conntrack -L | wc -l

# Simulate many connections (from client)
for i in {1..100}; do curl -s http://example.com &; done

# Check conntrack again
conntrack -L | wc -l
# Should show increased connections

# Check for conntrack errors
dmesg | grep conntrack
```

**Pass Criteria:**
- ✅ Connection tracking works
- ✅ No conntrack errors under load

---

## Automated Testing

### Test 23: Pentest Tools (Internal)

Run automated internal security tests.

```bash
# Enable pentest-tools module
fmf.router.pentest-tools.enable = true;

# After rebuilding, run tests
router-pentest-internal

# Review output:
# - Firewall status
# - SSH configuration
# - Zone setup
# - Kernel hardening
# - Service exposure
```

**Pass Criteria:**
- ✅ All security checks pass
- ✅ No critical issues reported

### Test 24: Pentest Tools (External)

Run automated external security tests.

```bash
# From external network
curl -s ifconfig.me  # Get WAN IP

# Run external pentest
router-pentest-external <WAN_IP>

# Review output:
# - Open ports
# - Service versions
# - SSH exposure
# - Dangerous services
```

**Pass Criteria:**
- ✅ No unexpected services exposed
- ✅ No critical vulnerabilities

### Test 25: Pentest Tools (Zones)

Run zone isolation tests.

```bash
# On router
router-pentest-zones

# Follow interactive guide to test:
# - Zone connectivity
# - Inter-zone routing
# - Isolation enforcement
```

**Pass Criteria:**
- ✅ All zone isolation tests pass
- ✅ Inter-zone routes work as configured

---

## Troubleshooting Tests

### Test 26: Service Status

Check all critical services are running.

```bash
# Check all router services
systemctl status systemd-networkd
systemctl status dnsmasq
systemctl status nftables
systemctl status sshd
systemctl status fail2ban

# Check for failed services
systemctl --failed
```

**Pass Criteria:**
- ✅ All services are active
- ✅ No failed services

### Test 27: Log Review

Review logs for errors.

```bash
# System logs
journalctl -xe

# Network logs
journalctl -u systemd-networkd -n 100

# DHCP/DNS logs
journalctl -u dnsmasq -n 100

# Firewall logs
journalctl -u nftables -n 100

# SSH logs
journalctl -u sshd -n 100

# Security logs
journalctl -u fail2ban -n 100
```

**Pass Criteria:**
- ✅ No critical errors
- ✅ No repeated warnings

### Test 28: Configuration Consistency

Verify running configuration matches declared configuration.

```bash
# Check interface IPs
ip addr show | grep inet

# Check firewall rules
nft list ruleset > /tmp/nft-rules.txt
# Review /tmp/nft-rules.txt

# Check dnsmasq config
cat /etc/dnsmasq.conf

# Check generated systemd network configs
ls -la /etc/systemd/network/
cat /etc/systemd/network/*
```

**Pass Criteria:**
- ✅ Running config matches declared config
- ✅ No unexpected configuration

---

## Test Checklists

### Basic Router Checklist

- [ ] All interfaces are UP
- [ ] IP addresses are correct
- [ ] IP forwarding is enabled
- [ ] NAT is working
- [ ] Internet connectivity works
- [ ] DNS resolution works
- [ ] Firewall is active

### Zone Configuration Checklist

- [ ] All VLAN interfaces exist
- [ ] VLAN IPs are correct
- [ ] Zones are isolated (full/partial/none)
- [ ] Inter-zone routes work
- [ ] Zone internet access works (if allowed)
- [ ] Per-zone DHCP works
- [ ] Per-zone DNS works

### Security Checklist

- [ ] SSH is LAN-only
- [ ] fail2ban is active
- [ ] No unexpected WAN exposure
- [ ] Kernel hardening applied
- [ ] Port forwards work correctly
- [ ] Default firewall policy is DROP
- [ ] Security audit passes

### Production Readiness Checklist

- [ ] All basic tests pass
- [ ] All zone tests pass
- [ ] All security tests pass
- [ ] Performance is acceptable
- [ ] No errors in logs
- [ ] Configuration is backed up
- [ ] Rollback plan is ready

---

## Continuous Testing

### Daily Monitoring

```bash
# Check system status
systemctl --failed

# Check logs for errors
journalctl -p err -n 50

# Check active connections
conntrack -L | wc -l

# Check DHCP leases
cat /var/lib/dnsmasq/dnsmasq.leases | wc -l
```

### Weekly Verification

```bash
# Run security check
router-security-check

# Check for NixOS updates
nix flake update

# Review fail2ban bans
fail2ban-client status sshd

# Check disk usage
df -h
```

### Monthly Audits

```bash
# Full security scan (from external)
nmap -Pn -sV -p- <WAN_IP>

# Review all firewall rules
nft list ruleset

# Review all inter-zone routes
router-zones

# Update and reboot
nixos-rebuild switch --flake .#router
reboot
```

---

## Regression Testing

After making configuration changes, run this regression test suite:

```bash
#!/usr/bin/env bash
# router-regression-test.sh

echo "=== Router Regression Test Suite ==="

echo "1. Testing basic connectivity..."
ping -c 4 1.1.1.1 || echo "FAIL: Internet connectivity"

echo "2. Testing DNS..."
dig @192.169.1.1 google.com || echo "FAIL: DNS resolution"

echo "3. Testing firewall..."
nft list ruleset > /dev/null || echo "FAIL: Firewall not loaded"

echo "4. Testing services..."
systemctl is-active systemd-networkd || echo "FAIL: systemd-networkd"
systemctl is-active dnsmasq || echo "FAIL: dnsmasq"
systemctl is-active nftables || echo "FAIL: nftables"
systemctl is-active sshd || echo "FAIL: sshd"

echo "5. Testing zones (if enabled)..."
if [ -f /run/current-system/sw/bin/router-zones ]; then
  router-zones || echo "FAIL: Zones not configured"
fi

echo "=== Test Complete ==="
```

Run after every configuration change to ensure nothing broke.

---

## Conclusion

This testing guide provides comprehensive procedures for validating the Campground router modules. Follow these tests to ensure:

1. **Basic functionality works** (routing, NAT, DNS, DHCP)
2. **Security is properly configured** (firewall, SSH, fail2ban)
3. **Zones are isolated correctly** (VLAN, firewall, inter-zone routes)
4. **Performance is acceptable** (throughput, latency)
5. **No regressions after changes**

For automated testing, enable `fmf.router.pentest-tools` and use the built-in scripts:
- `router-pentest-internal` - Internal security tests
- `router-pentest-external <WAN_IP>` - External security tests
- `router-pentest-zones` - Zone isolation tests

Always test configuration changes in a VM or lab environment before deploying to production.
