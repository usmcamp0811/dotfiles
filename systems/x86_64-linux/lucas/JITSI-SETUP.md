# Jitsi Meet Setup on Lucas

This document describes the Jitsi Meet deployment on the Lucas host.

## Configuration

**Host**: lucas.aicampground.com  
**Jitsi URL**: https://meet.aicampground.com  
**Vault Path**: `secret/campground/jitsi`

### Enabled Features

- ✅ Jitsi Meet web interface
- ✅ Jitsi Videobridge (media routing)
- ✅ Jicofo (conference focus)
- ✅ Prosody XMPP server
- ✅ Coturn TURN server (WebRTC connectivity)
- ✅ ACME/Let's Encrypt SSL certificates
- ✅ Vault-based secret management
- ✅ Custom branding (no Jitsi watermark)

### Configuration Details

```nix
fmf.services.jitsi = {
  enable = true;
  hostName = "meet.aicampground.com";
  
  acme = {
    enable = true;
    email = "matt@aicampground.com";
  };
  
  vault = {
    enable = true;
    vault-path = "secret/campground/jitsi";
    kvVersion = "v2";
  };
  
  coturn = {
    enable = true;
    port = 3478;
    minPort = 49152;
    maxPort = 49252;
  };
  
  interfaceConfig = {
    SHOW_JITSI_WATERMARK = false;
    DEFAULT_BACKGROUND = "#1a1a1a";
    VERTICAL_FILMSTRIP = true;
    TOOLBAR_ALWAYS_VISIBLE = false;
  };
  
  config = {
    enableWelcomePage = true;
    prejoinPageEnabled = true;
    startAudioMuted = 10;
    startVideoMuted = 10;
    p2p.enabled = true;
  };
};
```

## Initial Setup

### 1. Configure DNS

Ensure DNS is configured to point to Lucas:

```bash
# Check current DNS
dig meet.aicampground.com

# Should return Lucas's IP address
```

### 2. Setup Vault Secrets

Run the provided setup script:

```bash
cd /config/systems/x86_64-linux/lucas
./setup-jitsi-secrets.sh
```

Or manually:

```bash
# Login to Vault
vault login

# Generate and store secrets
vault kv put secret/campground/jitsi \
  TURN_SECRET="$(openssl rand -hex 32)" \
  VIDEOBRIDGE_SECRET="$(openssl rand -hex 32)"
```

### 3. Deploy Configuration

From the campground flake directory:

```bash
cd /glusterfs/shared/campground
nix flake update fmf
sudo nixos-rebuild switch --flake .#lucas
```

Or from the fmf-flake directory:

```bash
cd ~/code/campground/fmf-flake
git pull
sudo nixos-rebuild switch --flake .#lucas
```

### 4. Verify Deployment

Check all services are running:

```bash
# Main Jitsi services
systemctl status jitsi-videobridge2
systemctl status jicofo
systemctl status prosody
systemctl status coturn
systemctl status nginx

# Vault Agent
systemctl status vault-agent@jitsi-secrets

# Check logs
journalctl -u jitsi-videobridge2 -f
journalctl -u jicofo -f
journalctl -u prosody -f
journalctl -u coturn -f
```

### 5. Verify Secrets

Check that Vault Agent retrieved the secrets:

```bash
ls -la /tmp/detsys-vault/jitsi-*
# Should show:
# -rw------- jitsi-turn-secret
# -rw-r----- videobridge-secret
```

### 6. Test Access

Open a browser and navigate to:
```
https://meet.aicampground.com
```

You should see the Jitsi Meet interface.

## Network Configuration

### Required Ports

The following ports are automatically opened by the Jitsi module:

| Port | Protocol | Service | Description |
|------|----------|---------|-------------|
| 80 | TCP | HTTP | Redirects to HTTPS |
| 443 | TCP | HTTPS | Jitsi web interface |
| 3478 | TCP/UDP | TURN | Coturn TURN server |
| 10000 | UDP | JVB | Jitsi Videobridge media |
| 49152-49252 | TCP/UDP | TURN Relay | Coturn relay ports |

### Firewall Verification

```bash
# Check firewall rules
iptables -L -n -v | grep -E "(80|443|3478|10000)"

# Check listening ports
ss -tlnp | grep -E ":(80|443|3478)"
ss -ulnp | grep -E ":(3478|10000)"
```

## Monitoring

### Service Health Checks

```bash
# Videobridge health
curl http://localhost:8080/about/health

# Videobridge statistics
curl http://localhost:8080/colibri/stats

# Check Prosody
prosodyctl status

# Check Coturn
systemctl status coturn
```

### Logs

```bash
# All Jitsi logs
journalctl -u jitsi-videobridge2 -u jicofo -u prosody -u coturn -f

# Specific service logs
journalctl -u jitsi-videobridge2 -n 100
journalctl -u jicofo -n 100
journalctl -u prosody -n 100
journalctl -u coturn -n 100
journalctl -u nginx -n 100

# Vault Agent logs
journalctl -u vault-agent@jitsi-secrets -f
```

## Troubleshooting

### ACME/SSL Certificate Issues

```bash
# Check ACME status
systemctl status acme-meet.aicampground.com

# Check nginx logs
journalctl -u nginx -f

# Test certificate
openssl s_client -connect meet.aicampground.com:443 -showcerts

# Manually renew certificate
systemctl restart acme-meet.aicampground.com
```

### Vault Secrets Not Loading

```bash
# Check Vault Agent status
systemctl status vault-agent@jitsi-secrets
journalctl -u vault-agent@jitsi-secrets -f

# Verify Vault is accessible
curl -k https://vault.lan.aicampground.com/v1/sys/health

# Check role-id and secret-id files
ls -la /var/lib/vault/lucas/

# Test Vault authentication
vault login -method=approle \
  role_id="$(cat /var/lib/vault/lucas/role-id)" \
  secret_id="$(cat /var/lib/vault/lucas/secret-id)"

# Verify secrets exist in Vault
vault kv get secret/campground/jitsi
```

### Services Not Starting

```bash
# Check service dependencies
systemd-analyze critical-chain jitsi-videobridge2.service
systemd-analyze critical-chain jicofo.service

# Check for errors
systemctl status jitsi-videobridge2 --no-pager -l
systemctl status jicofo --no-pager -l
systemctl status prosody --no-pager -l

# Restart all Jitsi services
systemctl restart prosody
systemctl restart jicofo
systemctl restart jitsi-videobridge2
systemctl restart coturn
```

### No Audio/Video in Meetings

```bash
# Check Videobridge is accessible
curl http://localhost:8080/about/health

# Check TURN server
turnutils_uclient -v meet.aicampground.com

# Verify firewall allows UDP 10000
ss -ulnp | grep 10000

# Check logs for errors
journalctl -u jitsi-videobridge2 -u coturn -f
```

### P2P Connection Issues

```bash
# Check TURN server configuration
journalctl -u coturn -n 50

# Verify TURN secret is correct
cat /tmp/detsys-vault/jitsi-turn-secret

# Test TURN server with turnutils
nix-shell -p coturn --run "turnutils_uclient -v meet.aicampground.com"
```

## Maintenance

### Secret Rotation

To rotate secrets:

```bash
# Generate new secrets
vault kv put secret/campground/jitsi \
  TURN_SECRET="$(openssl rand -hex 32)" \
  VIDEOBRIDGE_SECRET="$(openssl rand -hex 32)"

# Restart Vault Agent (will auto-restart Jitsi services)
systemctl restart vault-agent@jitsi-secrets

# Or manually restart services
systemctl restart coturn
systemctl restart jitsi-videobridge2
systemctl restart jicofo
systemctl restart prosody
```

### Updating Jitsi

Jitsi is updated via NixOS package updates:

```bash
cd /glusterfs/shared/campground
nix flake update fmf
sudo nixos-rebuild switch --flake .#lucas
```

### Backup

Important files to backup:

- `/var/lib/jitsi-meet/` - Auto-generated secrets and certificates
- Vault secrets at `secret/campground/jitsi`
- DNS configuration

## Integration with Traefik

If you want to use Traefik instead of nginx (Lucas already has public-hosting suite enabled):

```nix
fmf.services.jitsi = {
  enable = true;
  hostName = "meet.aicampground.com";
  
  # Disable nginx, use Traefik
  nginx.enable = false;
  acme.enable = false;  # Let Traefik handle SSL
  
  # ... rest of config
};
```

Then configure Traefik to proxy to Jitsi Meet.

## References

- Jitsi Module Documentation: `/config/modules/nixos/services/jitsi/README.md`
- Vault Setup Guide: `/config/modules/nixos/services/jitsi/VAULT_SETUP.md`
- Testing Guide: `/config/modules/nixos/services/jitsi/TEST.md`
- Jitsi Handbook: https://jitsi.github.io/handbook/
- NixOS Jitsi Options: https://search.nixos.org/options?query=services.jitsi-meet
