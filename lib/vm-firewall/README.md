# VM Firewall Library

Automatic firewall rule generation for microVMs based on introspection of service configurations.

## Overview

This library provides functions to automatically inspect NixOS VM configurations and generate appropriate firewall rules based on:
- Which services are running in each VM
- Which ports those services listen on
- The risk level of the VM (public-facing vs LAN-only vs isolated)

This eliminates manual firewall rule management and ensures rules stay in sync with service configurations.

## Core Functions

### `getVmPorts`

Extracts all listening ports from a VM's service configuration.

**Parameters:**
- `nixosConfigurations`: The flake's nixosConfigurations attrset
- `vmName`: Name of the VM to inspect (e.g., "vm-vaultwarden")

**Returns:**
```nix
{
  tcp = [8989 3011 3012];  # List of TCP ports
  udp = [];                 # List of UDP ports
}
```

**Example:**
```nix
getVmPorts {
  inherit nixosConfigurations;
  vmName = "vm-vaultwarden";
}
# => { tcp = [8989]; udp = []; }
```

### `getVmIp`

Retrieves the IP address of a VM from its systemd-networkd configuration.

**Parameters:**
- `nixosConfigurations`: The flake's nixosConfigurations attrset
- `vmName`: Name of the VM

**Returns:** String IP address or `null`

**Example:**
```nix
getVmIp {
  inherit nixosConfigurations;
  vmName = "vm-vaultwarden";
}
# => "10.8.0.13"
```

### `getAllVms`

Lists all VM configurations (anything starting with "vm-").

**Parameters:**
- `nixosConfigurations`: The flake's nixosConfigurations attrset

**Returns:** List of VM names

**Example:**
```nix
getAllVms { inherit nixosConfigurations; }
# => ["vm-photos" "vm-vaultwarden" "vm-nextcloud" "vm-mealie"]
```

### `generateVmFirewallRules`

Generates firewall rules for a specific VM based on its risk level.

**Parameters:**
- `nixosConfigurations`: The flake's nixosConfigurations attrset
- `vmName`: Name of the VM
- `riskLevel`: One of "public", "lan", or "isolated" (default: "lan")
- `allowedLanServices`: Services in LAN that VMs can access (default: DNS + Vault)

**Risk Levels:**
- **`"public"`**: Public-facing VMs (e.g., via pub-traefik)
  - Can access: DNS, Vault, Internet
  - Cannot access: Other LAN services
  - LAN can access: All VM ports

- **`"lan"`**: Internal LAN services (default)
  - Can access: DNS, Vault, Internet, potentially other LAN services
  - LAN can access: All VM ports

- **`"isolated"`**: Fully isolated VMs
  - Can access: DNS, Vault only
  - Cannot access: Internet or other LAN services
  - LAN can access: All VM ports (for management)

**Returns:** List of firewall rule attrsets

**Example:**
```nix
generateVmFirewallRules {
  inherit nixosConfigurations;
  vmName = "vm-vaultwarden";
  riskLevel = "public";
}
# => [
#   { from = "vm"; to = ["lan"]; destinationIPs = ["10.8.0.2"]; ports = [53]; ... }
#   { from = "lan"; to = ["vm"]; destinationIPs = ["10.8.0.13"]; ports = [8989]; ... }
#   ...
# ]
```

### `generateAllVmFirewallRules`

Generates firewall rules for ALL VMs automatically.

**Parameters:**
- `nixosConfigurations`: The flake's nixosConfigurations attrset
- `publicVms`: List of VM names that are public-facing (default: `[]`)
- `isolatedVms`: List of VM names that should be isolated (default: `[]`)

**Returns:** Flattened list of all firewall rules for all VMs

**Example:**
```nix
generateAllVmFirewallRules {
  inherit nixosConfigurations;
  publicVms = ["vm-nextcloud" "vm-vaultwarden" "vm-mealie"];
  isolatedVms = [];
}
```

### `getTraefikProxiedServices`

Helper function to extract which services are being proxied by Traefik.

**Parameters:**
- `traefikConfig`: The traefik dynamic configuration

**Returns:** Attrset mapping router names to service info

**Example:**
```nix
getTraefikProxiedServices {
  traefikConfig = config.services.traefik.dynamicConfigOptions;
}
# => {
#   nextcloud = { service = "nextcloud"; domain = "Host(`cloud.aicampground.com`)"; };
#   vaultwarden = { service = "vaultwarden"; domain = "Host(`vault.aicampground.com`)"; };
# }
```

## Usage in Router Configuration

### Basic Usage

```nix
# In your flake.nix or router module
let
  vmFirewall = import ./lib/vm-firewall { inherit lib; };
in
{
  # Generate rules for all VMs, marking public ones
  campground.router.zones.interZoneRoutes = vmFirewall.generateAllVmFirewallRules {
    nixosConfigurations = inputs.self.nixosConfigurations;
    publicVms = [
      "vm-nextcloud"
      "vm-vaultwarden"
      "vm-mealie"
      "vm-authentik"
    ];
  };
}
```

### Advanced Usage - Per-VM Risk Levels

```nix
let
  vmFirewall = import ./lib/vm-firewall { inherit lib; };

  # Manually specify rules for specific VMs
  customVmRules = [
    (vmFirewall.generateVmFirewallRules {
      nixosConfigurations = inputs.self.nixosConfigurations;
      vmName = "vm-nextcloud";
      riskLevel = "public";
    })
    (vmFirewall.generateVmFirewallRules {
      nixosConfigurations = inputs.self.nixosConfigurations;
      vmName = "vm-photos";
      riskLevel = "lan"; # Internal only
    })
  ];
in
{
  campground.router.zones.interZoneRoutes = lib.flatten customVmRules;
}
```

### Custom Allowed Services

```nix
vmFirewall.generateVmFirewallRules {
  nixosConfigurations = inputs.self.nixosConfigurations;
  vmName = "vm-photos";
  riskLevel = "lan";
  allowedLanServices = {
    dns = {
      ip = "10.8.0.2";
      ports = { udp = [53]; tcp = [53]; };
    };
    vault = {
      ip = "10.8.0.3";
      ports = { tcp = [8200 443]; };
    };
    # Add custom service
    nfs = {
      ip = "10.8.0.194";  # webb
      ports = { tcp = [2049]; };
    };
  };
}
```

## Integration with Traefik

You can automatically determine which VMs are public-facing by inspecting Traefik configuration:

```nix
let
  # Extract public-facing services from traefik config
  pubTraefikConfig = config.services.traefik.dynamicConfigOptions;
  proxiedServices = vmFirewall.getTraefikProxiedServices {
    traefikConfig = pubTraefikConfig;
  };

  # Map service names to VM names (you may need custom logic here)
  publicVmNames = map (svc: "vm-${svc}") (attrValues proxiedServices);
in
{
  campground.router.zones.interZoneRoutes = vmFirewall.generateAllVmFirewallRules {
    nixosConfigurations = inputs.self.nixosConfigurations;
    publicVms = publicVmNames;
  };
}
```

## Architecture Decisions

### Why Inspect Services Instead of Manual Lists?

**Automatic Port Discovery:**
- Ports are extracted from `fmf.services.*.port` configuration
- When you change a service's port, firewall rules update automatically
- No manual synchronization needed

**Risk-Based Segmentation:**
- Public VMs get minimal LAN access (DNS + Vault only)
- LAN VMs get more permissive rules
- Isolated VMs get locked down completely

**Single Source of Truth:**
- Service configuration drives firewall rules
- Adding a new service to a VM automatically opens required ports
- Removing a service automatically closes ports

### VLAN Strategy

Two approaches for VM network isolation:

**Option 1: IP-based filtering in current LAN**
- Keep VMs in 10.8.0.0/24
- Use source IP-based nftables rules
- Simpler, no network reconfiguration
- Uses this library to generate rules

**Option 2: Dedicated VM VLAN**
- Create VLAN 40 (10.8.40.0/24) for VMs
- Requires bridge reconfiguration on VM hosts
- Cleaner layer-2 separation
- Still uses this library for layer-3/4 rules

## Example: Complete Router Configuration

```nix
{ inputs, config, lib, ... }:
let
  vmFirewall = import ./lib/vm-firewall { inherit lib; };
in
{
  campground.router = {
    enable = true;

    zones = {
      enable = true;

      # Existing zones...
      zones.lan = { ... };
      zones.wifi = { ... };
      zones.iot = { ... };
      zones.guest = { ... };

      # VM zone (optional - for VLAN approach)
      zones.vm = {
        vlanId = 40;
        subnet = "10.8.40.0/24";
        gateway = "10.8.40.1";
        dhcp.enable = true;
        allowInternet = true;
        isolation = "full";  # Block all by default
      };

      # Auto-generated VM firewall rules
      interZoneRoutes = vmFirewall.generateAllVmFirewallRules {
        nixosConfigurations = inputs.self.nixosConfigurations;
        publicVms = [
          "vm-nextcloud"
          "vm-vaultwarden"
          "vm-mealie"
          "vm-authentik"
        ];
      };
    };
  };
}
```

## Extending the Library

### Adding Custom Port Detection

If you have services that don't use `fmf.services.*.port`, extend `extractServicePorts`:

```nix
extractServicePorts = serviceName: serviceConfig:
  let
    # Standard port detection
    port = serviceConfig.port or null;

    # Custom detection for nginx
    nginxPorts = if serviceName == "nginx"
      then [80 443]
      else [];

    # Combine
    allPorts = filter (p: p != null) ([port] ++ nginxPorts);
  in
  { tcp = allPorts; };
```

### Adding Custom Risk Levels

You can define custom risk levels:

```nix
riskRules =
  if riskLevel == "dmz" then [
    # DMZ-specific rules
    { from = "vm"; to = ["internet"]; ... }
  ]
  else if riskLevel == "public" then [
    # Public rules...
  ]
  # ... etc
```

## Future Enhancements

- [ ] Automatic detection of public VMs from Traefik config
- [ ] Support for service-to-service rules (VM-to-VM)
- [ ] Integration with `systemd.services.*.ports` for non-fmf services
- [ ] Automatic VLAN assignment based on risk level
- [ ] Support for IPv6 rules
- [ ] Health check rules for monitoring systems
