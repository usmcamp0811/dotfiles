# Host record for vm-adguard: what the fleet derives leases, DNS, port forwards and MicroVM hosting from.
# Spec: docs/HOST-MODEL.md. Edit it here; run `fleet` afterwards to regenerate network/generated/.
{...}: {
  fmf.host = {
    kind = "microvm";
    expose = [
      {
        description = "vm-AdGuard Web UI via port 80 -> 3000 (optional)";
        destPort = 3000;
        port = 80;
        proto = "tcp";
      }
    ];
    network = {
      interfaces = {
        lan = {
          ip = "192.169.1.2";
          mac = "02:00:00:00:00:30";
          zone = "lan"; # static: the guest configures this address itself (see ./default.nix)
        };
      };
    };
    placement = {
      restartIfChanged = true;
      runsOn = "blue-ridge";
    };
  };
}
