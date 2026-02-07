# Vault MicroVM

This is a lightweight MicroVM that runs on the `blue-ridge` host. It's designed to run critical infrastructure services like Vault and Traefik that should be coupled with the router - if the router is down, these services being down is the same failure domain.

## Architecture

- **Hypervisor**: QEMU (via microvm.nix)
- **Resources**: 2 vCPU, 2GB RAM
- **Storage**: 10GB persistent volume for Vault data
- **Networking**: TAP interface bridged to host network (appears as separate device on LAN)
- **Nix Store**: Shared with host via virtiofs (saves disk space)

## Network Configuration

The VM uses a TAP interface (`vm-vault`) with a static MAC address `02:00:00:00:00:01`. This ensures:
- Consistent DHCP assignments (configure static lease in router)
- VM appears as a separate device on the network
- Can be accessed from any device on the LAN

When you enable the router module on blue-ridge, you can add a static DHCP lease:
```nix
campground.router.dhcp.staticLeases = [
  {
    hostname = "vault";
    mac = "02:00:00:00:00:01";
    ip = "192.168.1.10";  # Choose your preferred IP
    description = "Vault MicroVM";
  }
];
```

## Building and Running

### Build the MicroVM

```bash
# Build the MicroVM
nix build .#nixosConfigurations.vault.config.microvm.declaredRunner

# Or build from blue-ridge
nix build .#nixosConfigurations.blue-ridge.config.microvm.vms.vault.runner
```

### Deploy to blue-ridge

The MicroVM is managed by the blue-ridge host. Deploy blue-ridge and the MicroVM will be automatically configured:

```bash
# Deploy blue-ridge (includes MicroVM setup)
sudo nixos-rebuild switch --flake .#blue-ridge
```

### Managing the MicroVM

On the blue-ridge host:

```bash
# Start the MicroVM
systemctl start microvm@vault

# Stop the MicroVM
systemctl stop microvm@vault

# Enable auto-start on boot
systemctl enable microvm@vault

# Check status
systemctl status microvm@vault

# View logs
journalctl -u microvm@vault -f
```

## Services

### Vault (example configuration included)

Uncomment the vault service configuration in `default.nix` to enable Vault:

```nix
services.vault = {
  enable = true;
  address = "0.0.0.0:8200";
  storageBackend = "file";
  storagePath = "/var/lib/vault";
};
```

## Adding More Services

This VM can host multiple critical services:
- Vault (secrets management)
- Traefik (reverse proxy)
- CoreDNS (DNS)
- Certificate management (cert-manager, etc.)

Just add the service configuration to `default.nix` and rebuild.

## Resource Adjustments

Edit the resource allocation in `default.nix`:

```nix
microvm = {
  vcpu = 2;      # Adjust CPU cores
  mem = 2048;    # Adjust RAM (MB)
  volumes = [
    {
      image = "vault-data.img";
      mountPoint = "/var/lib/vault";
      size = 10240;  # Adjust storage (MB)
    }
  ];
};
```

## Troubleshooting

### VM won't start
- Check that blue-ridge has `microvm.host.enable = true`
- Verify TAP interface permissions: `ip link show vm-vault`
- Check logs: `journalctl -u microvm@vault -n 50`

### Network not working
- Verify bridge exists: `ip link show br0`
- Check TAP interface is in bridge: `bridge link show`
- Verify firewall allows bridge: `networking.firewall.trustedInterfaces = ["br0"]`

### Can't SSH to VM
- Check VM got IP from DHCP: `systemctl status microvm@vault`
- Verify SSH keys are correct in `default.nix`
- Check firewall on VM allows SSH
