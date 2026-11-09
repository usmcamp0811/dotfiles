# Host record for vm-websites: what the fleet derives leases, DNS, port forwards and MicroVM hosting from.
# Spec: docs/HOST-MODEL.md. Edit it here; run `fleet` afterwards to regenerate network/generated/.
{...}: {
  fmf.host = {
    kind = "microvm";
    network = {
      interfaces = {
        lan = {
          ip = "192.169.1.11";
          mac = "02:00:00:00:00:11";
          static = false; # the guest takes this address from DHCP (a lease reserves it)
          zone = "lan";
        };
      };
    };
    # Starts after the Vault VM: it reads its secrets through vault-agent.
    boot.after = ["vm-vault"];
    placement = {
      restartIfChanged = true;
      runsOn = "blue-ridge";
    };
  };
}
