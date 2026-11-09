# Host record for vm-vault: what the fleet derives leases, DNS, port forwards and MicroVM hosting from.
# Spec: docs/HOST-MODEL.md. Edit it here; run `fleet` afterwards to regenerate network/generated/.
{...}: {
  fmf.host = {
    kind = "microvm";
    network = {
      interfaces = {
        lan = {
          ip = "192.169.1.10";
          mac = "02:00:00:00:00:10";
          static = false; # the guest takes this address from DHCP (a lease reserves it)
          zone = "lan";
        };
      };
    };
    # Vault auto-unseals with clevis, which asks tang on the hypervisor.
    boot.hostUnits = ["tang.socket"];
    placement = {
      runsOn = "blue-ridge";
      # restartIfChanged is deliberately NOT set: restarting this VM seals Vault and blocks everything that
      # reads secrets. Unset keeps microvm's default, which is false for a flake-based VM.
    };
  };
}
