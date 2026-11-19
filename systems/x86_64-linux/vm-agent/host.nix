# Host record for vm-agent (demo; see ./README.md). Spec: docs/HOST-MODEL.md.
# No `placement.runsOn`: this VM is standby here, so no hypervisor in this flake gets a stanza for it.
# The live copy runs in the downstream Campground flake.
{...}: {
  fmf.host = {
    kind = "microvm";
    network = {
      derive = true;
      interfaces = {
        lan = {
          ip = "192.169.1.26";
          mac = "02:00:00:00:00:26";
          zone = "lan";
        };
      };
    };
  };
}
