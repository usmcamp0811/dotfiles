# Jitsi Module Testing Guide

This document provides testing procedures for the Jitsi Meet NixOS module.

## Syntax Validation

### Test Module Discovery

Verify the module is discoverable in the flake:

```bash
cd /path/to/fmf-flake
nix flake show 2>&1 | grep jitsi
```

**Expected Output:**
```
evaluating 'nixosModules.services/jitsi'...
│   ├───"services/jitsi": NixOS module
```

### Test Module Evaluation

Verify the module can be evaluated without errors:

```bash
nix-instantiate --eval --strict -E '
  let
    flake = builtins.getFlake "git+file:///path/to/fmf-flake";
    pkgs = import <nixpkgs> {};
  in
    (flake.nixosModules."services/jitsi" {
      inherit pkgs;
      lib = pkgs.lib;
      config = {};
    }).options.fmf.services.jitsi.enable.description or "missing"
'
```

**Expected Output:**
```
"Enable Jitsi Meet video conferencing"
```

## Integration Testing

### Minimal Configuration Test

Create a test system configuration:

```nix
# test-jitsi.nix
{ config, pkgs, ... }:

{
  imports = [
    # Your fmf-flake modules
  ];

  fmf.services.jitsi = {
    enable = true;
    hostName = "meet.test.local";
    
    # Disable ACME for testing
    acme.enable = false;
    
    # Disable Vault for initial testing
    vault.enable = false;
    
    # Use minimal TURN config
    coturn = {
      enable = true;
      port = 3478;
    };
  };
}
```

Build the test configuration:

```bash
nixos-rebuild build-vm -I nixos-config=./test-jitsi.nix
```

### Full Configuration Test

Test with all features enabled:

```nix
# test-jitsi-full.nix
{ config, pkgs, ... }:

{
  imports = [ ];

  fmf.services.jitsi = {
    enable = true;
    hostName = "meet.example.com";
    
    acme = {
      enable = true;
      email = "admin@example.com";
    };
    
    vault = {
      enable = true;
      vault-path = "secret/test/jitsi";
      kvVersion = "v2";
    };
    
    coturn.enable = true;
    nginx.enable = true;
    videobridge.enable = true;
    jicofo.enable = true;
    prosody.enable = true;
  };
}
```

## Runtime Testing

### Service Status Checks

After deploying, verify all services are running:

```bash
# Check main Jitsi services
systemctl status jitsi-videobridge2
systemctl status jicofo
systemctl status prosody
systemctl status coturn
systemctl status nginx

# Check Vault Agent (if enabled)
systemctl status vault-agent@jitsi-secrets
```

### Port Verification

Verify all required ports are listening:

```bash
# Check TCP ports
ss -tlnp | grep -E ":(80|443|3478)"

# Check UDP ports
ss -ulnp | grep -E ":(10000|3478)"

# Verify firewall rules
iptables -L -n -v | grep -E "(80|443|3478|10000|49152|49252)"
```

### Secret Files Verification

If Vault is enabled, verify secrets are present:

```bash
# Check secret files exist
ls -la /tmp/detsys-vault/jitsi-*

# Verify permissions (should be 0600)
stat /tmp/detsys-vault/jitsi-turn-secret
stat /tmp/detsys-vault/jitsi-component-secret
stat /tmp/detsys-vault/videobridge-secret

# Verify ownership
ls -la /tmp/detsys-vault/ | grep jitsi
```

### Web Interface Test

Test the web interface is accessible:

```bash
# Test HTTP (should redirect to HTTPS if ACME enabled)
curl -I http://meet.example.com

# Test HTTPS
curl -k -I https://meet.example.com

# Test specific endpoint
curl -k https://meet.example.com/config.js
```

### TURN Server Test

Verify the TURN server is working:

```bash
# Install turnutils (part of coturn package)
nix-shell -p coturn

# Test TURN server
turnutils_uclient -v -u testuser -w testsecret \
  -s $(cat /tmp/detsys-vault/jitsi-turn-secret) \
  meet.example.com
```

### Component Communication Test

Check logs for successful component registration:

```bash
# Videobridge logs
journalctl -u jitsi-videobridge2 -n 100 | grep -i "registered"

# Jicofo logs
journalctl -u jicofo -n 100 | grep -i "videobridge"

# Prosody logs
journalctl -u prosody -n 100 | grep -i "component"
```

## Functional Testing

### Create Test Meeting

1. Open web browser and navigate to: `https://meet.example.com`
2. Enter a room name and click "Go"
3. Verify video/audio preview appears
4. Join the meeting
5. Test features:
   - Audio mute/unmute
   - Video mute/unmute
   - Screen sharing
   - Chat
   - Participant list

### Multi-Participant Test

1. Open meeting in multiple browsers/devices
2. Verify all participants can see each other
3. Test audio quality
4. Test video quality
5. Verify TURN server is used (check coturn logs)

```bash
# Monitor TURN server usage
journalctl -u coturn -f
```

### P2P Connection Test

1. Join meeting with exactly 2 participants
2. Verify P2P connection is established (check browser console)
3. Add 3rd participant
4. Verify connection switches to JVB (Jitsi Videobridge)

## Performance Testing

### Resource Usage

Monitor resource usage during meetings:

```bash
# Overall system resources
htop

# Per-service CPU/Memory
systemd-cgtop

# Specific service stats
systemctl status jitsi-videobridge2
systemctl status coturn
systemctl status prosody
```

### Connection Limits

Test connection limits:

1. Join meeting with multiple participants (10, 20, 50, etc.)
2. Monitor Videobridge statistics
3. Check logs for errors or warnings

```bash
# Videobridge stats endpoint
curl http://localhost:8080/colibri/stats
```

## Troubleshooting Tests

### Test with Verbose Logging

Enable debug logging for troubleshooting:

```nix
{
  fmf.services.jitsi = {
    enable = true;
    # ... other config ...
    
    extraConfig = ''
      // Enable debug logging
      config.debug = true;
      config.logLevel = 'debug';
    '';
  };
}
```

### Common Issues

#### Issue: Services fail to start

**Test:**
```bash
# Check service logs
journalctl -xe

# Check specific service
journalctl -u jitsi-videobridge2 -n 100
journalctl -u jicofo -n 100
journalctl -u prosody -n 100
```

#### Issue: No audio/video

**Test:**
```bash
# Verify Videobridge is accessible
curl http://localhost:8080/about/health

# Check firewall
iptables -L -n -v

# Test TURN server
turnutils_uclient -v meet.example.com
```

#### Issue: SSL/TLS errors

**Test:**
```bash
# Verify certificates
openssl s_client -connect meet.example.com:443 -showcerts

# Check ACME status
systemctl status acme-meet.example.com

# Check nginx logs
journalctl -u nginx -f
```

#### Issue: Vault secrets not loading

**Test:**
```bash
# Check Vault Agent status
systemctl status vault-agent@jitsi-secrets

# Verify secrets exist in Vault
vault kv get secret/campground/jitsi

# Test Vault connectivity
curl -k https://vault.example.com:8200/v1/sys/health

# Check AppRole authentication
vault write auth/approle/login \
  role_id="$(cat /etc/vault/role-id)" \
  secret_id="$(cat /etc/vault/secret-id)"
```

## Cleanup

### Remove Test Configuration

```bash
# Stop services
systemctl stop jitsi-videobridge2
systemctl stop jicofo
systemctl stop prosody
systemctl stop coturn
systemctl stop nginx

# Remove configuration
nixos-rebuild switch

# Clean up test data
rm -rf /var/lib/jitsi-meet
rm -rf /tmp/detsys-vault/jitsi-*
```

## Continuous Integration

### Automated Testing Script

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Jitsi Module CI Test ==="

echo "1. Testing module syntax..."
nix flake show | grep -q "services/jitsi" || exit 1

echo "2. Testing module evaluation..."
nix-instantiate --eval --strict -E '
  let
    flake = builtins.getFlake "git+file://'$(pwd)'";
    pkgs = import <nixpkgs> {};
  in
    (flake.nixosModules."services/jitsi" {
      inherit pkgs;
      lib = pkgs.lib;
      config = {};
    }).options.fmf.services.jitsi.enable.description
' > /dev/null || exit 1

echo "3. Building test configuration..."
nixos-rebuild build-vm -I nixos-config=./test-jitsi.nix || exit 1

echo "=== All tests passed! ==="
```

## Test Checklist

- [ ] Module is discoverable in flake
- [ ] Module evaluates without errors
- [ ] Minimal configuration builds successfully
- [ ] Full configuration builds successfully
- [ ] All services start without errors
- [ ] Required ports are listening
- [ ] Firewall rules are configured correctly
- [ ] Vault secrets are retrieved (if enabled)
- [ ] Web interface is accessible
- [ ] TURN server responds to requests
- [ ] Components communicate successfully
- [ ] Audio/video works in test meeting
- [ ] Multiple participants can join
- [ ] P2P connections work
- [ ] Resource usage is acceptable
- [ ] Logs show no critical errors

## References

- [NixOS Testing](https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests)
- [Jitsi Meet Testing](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-manual)
- [Coturn Testing](https://github.com/coturn/coturn/wiki/turnserver#running)
