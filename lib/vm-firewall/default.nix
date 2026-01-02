{ lib, ... }:
with lib; rec {
  # Extract all listening ports from a VM's service configuration
  # Returns: { tcp = [port1 port2 ...]; udp = [port1 port2 ...]; }
  getVmPorts = { nixosConfigurations, vmName }:
    let
      vmConfig = nixosConfigurations.${vmName} or null;

      # Helper to extract port from a service config
      extractServicePorts = serviceName: serviceConfig:
        let
          port = serviceConfig.port or null;
          # Some services might have multiple ports
          ports = serviceConfig.ports or (if port != null then [port] else []);
          protocol = serviceConfig.protocol or "tcp"; # default to TCP
        in
        if serviceConfig.enable or false then
          { ${protocol} = ports; }
        else
          {};

      # Get all fmf.services from the VM
      fmfServices = vmConfig.config.fmf.services or {};

      # Extract ports from all enabled services
      allServicePorts = mapAttrs extractServicePorts fmfServices;

      # Merge all TCP/UDP ports
      mergePorts = protocol:
        unique (flatten (filter (p: p != null)
          (mapAttrsToList (name: ports: ports.${protocol} or []) allServicePorts)));

    in
    if vmConfig != null then {
      tcp = mergePorts "tcp";
      udp = mergePorts "udp";
    } else {
      tcp = [];
      udp = [];
    };

  # Get the IP address of a VM from its network configuration
  getVmIp = { nixosConfigurations, vmName }:
    let
      vmConfig = nixosConfigurations.${vmName} or null;
      # Try to get IP from systemd.network configuration
      networks = vmConfig.config.systemd.network.networks or {};
      lan0Config = networks."20-lan0" or null;
      addresses = if lan0Config != null then lan0Config.address or [] else [];
      # Extract first IP without CIDR
      firstAddr = if addresses != [] then head addresses else null;
      ip = if firstAddr != null then head (splitString "/" firstAddr) else null;
    in
    if vmConfig != null && ip != null then ip else null;

  # Determine if a VM is public-facing based on traefik configuration
  # You would pass the traefik config here to check if serviceName is routed
  isVmPublic = { traefikRouters, serviceName }:
    any (router: router.service == serviceName) (attrValues traefikRouters);

  # Get all VMs from nixosConfigurations that start with "vm-"
  getAllVms = { nixosConfigurations }:
    filter (name: hasPrefix "vm-" name) (attrNames nixosConfigurations);

  # Generate firewall rules for a specific VM based on its risk level
  # Risk levels: "public", "lan", "isolated"
  generateVmFirewallRules = {
    nixosConfigurations,
    vmName,
    riskLevel ? "lan",
    allowedLanServices ? {
      dns = { ip = "10.8.0.2"; ports = { udp = [53]; tcp = [53]; }; };
      vault = { ip = "10.8.0.3"; ports = { tcp = [8200 443]; }; };
    }
  }:
    let
      vmIp = getVmIp { inherit nixosConfigurations vmName; };
      vmPorts = getVmPorts { inherit nixosConfigurations vmName; };

      # Base rules that apply to all VMs
      baseRules = [
        # VM can access specific LAN services (DNS, Vault)
        {
          from = "vm";
          to = ["lan"];
          sourceIPs = optional (vmIp != null) vmIp;
          destinationIPs = [allowedLanServices.dns.ip];
          protocol = "udp";
          ports = allowedLanServices.dns.ports.udp;
          description = "${vmName} to DNS";
        }
        {
          from = "vm";
          to = ["lan"];
          sourceIPs = optional (vmIp != null) vmIp;
          destinationIPs = [allowedLanServices.vault.ip];
          protocol = "tcp";
          ports = allowedLanServices.vault.ports.tcp;
          description = "${vmName} to Vault";
        }
        # LAN can access all VM services
        {
          from = "lan";
          to = ["vm"];
          destinationIPs = optional (vmIp != null) vmIp;
          protocol = "tcp";
          ports = vmPorts.tcp;
          description = "LAN to ${vmName} (TCP)";
        }
      ] ++ optional (vmPorts.udp != []) {
        from = "lan";
        to = ["vm"];
        destinationIPs = optional (vmIp != null) vmIp;
        protocol = "udp";
        ports = vmPorts.udp;
        description = "LAN to ${vmName} (UDP)";
      };

      # Additional rules based on risk level
      riskRules =
        if riskLevel == "public" then [
          # Public VMs: strict isolation, no LAN access except DNS/Vault
          # Internet access via NAT is implicit
        ]
        else if riskLevel == "isolated" then [
          # Isolated VMs: no internet access, only DNS/Vault/LAN management
          # Would need additional firewall rule to block internet
        ]
        else [
          # LAN VMs: can access other LAN services (default, more permissive)
          # You could add specific service-to-service rules here
        ];

    in
    baseRules ++ riskRules;

  # Generate all firewall rules for all VMs
  generateAllVmFirewallRules = {
    nixosConfigurations,
    publicVms ? [], # List of VM names that are public-facing
    isolatedVms ? [], # List of VM names that should be fully isolated
  }:
    let
      allVms = getAllVms { inherit nixosConfigurations; };

      determineRiskLevel = vmName:
        if elem vmName publicVms then "public"
        else if elem vmName isolatedVms then "isolated"
        else "lan";

      vmRules = map (vmName:
        generateVmFirewallRules {
          inherit nixosConfigurations vmName;
          riskLevel = determineRiskLevel vmName;
        }
      ) allVms;

    in
    flatten vmRules;

  # Helper: Extract which services are proxied by traefik for a given VM
  # This can be used to determine if a VM is public-facing
  getTraefikProxiedServices = { traefikConfig }:
    let
      routers = traefikConfig.http.routers or {};
      # Map service name to list of domains
      serviceMap = mapAttrs (name: router: {
        service = router.service;
        domain = router.rule or "";
      }) routers;
    in
    serviceMap;
}
