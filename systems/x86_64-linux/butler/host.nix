# Host record for butler: its DHCP reservation on the LAN used to be written by hand in blue-ridge's zone
# leases; the fleet generates it from here now. Spec: docs/HOST-MODEL.md. Run `fleet` after editing.
{...}: {
  fmf.host = {
    kind = "physical";
    network = {
      interfaces = {
        lan = {
          ip = "192.169.1.101";
          mac = "60:6d:3c:c2:4a:6e";
          zone = "lan";
        };
      };
    };
  };
}
