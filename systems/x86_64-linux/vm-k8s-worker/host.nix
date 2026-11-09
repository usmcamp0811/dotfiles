# Host record for vm-k8s-worker: what the fleet derives leases, DNS, port forwards and MicroVM hosting from.
# Spec: docs/HOST-MODEL.md. Edit it here; run `fleet` afterwards to regenerate network/generated/.
{...}: {
  fmf.host = {
    kind = "microvm";
    # Not placed on a hypervisor: it keeps its lease and name, and is not started. Give it `placement.runsOn`
    # and run `fleet` when it is placed (its storage.nix already derives its shares).
    lifecycle = "standby";
    network = {
      # The guest configures itself from this record (link name, address, gateway, DNS and tap).
      derive = true;
      dns = ["192.169.1.2" "1.1.1.1" "8.8.8.8"]; # AdGuard first (a public resolver last); the zone default is AdGuard only
      interfaces = {
        lan = {
          ip = "192.169.1.51";
          mac = "02:00:00:00:00:51";
          zone = "lan";
        };
      };
    };
  };
}
