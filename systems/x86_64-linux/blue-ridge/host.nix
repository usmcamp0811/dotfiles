# Host record for blue-ridge (the router and the hypervisor of its MicroVMs). Spec: docs/HOST-MODEL.md.
# Its leases, port forwards and VM stanzas are generated into network/generated/ by `fleet`.
{...}: {
  fmf.host = {
    kind = "physical";
    network = {
      interfaces = {
        lan = {
          ip = "192.169.1.1";
          static = true;
          zone = "lan";
        };
      };
    };
  };
}
