# Network attachment for vm-lan-traefik (fmf.host; spec: docs/HOST-MODEL.md, phase 4). The interface's name on the
# hypervisor, where it differs from the default (the host name): Linux allows at most 15 characters, and the
# hypervisor's bridge rules refer to this name. It must match microvm.interfaces in ./default.nix.
{...}: {
  fmf.host.network.interfaces.lan.id = "vm-traefik-lan";
}
