# Network attachment for blue-ridge (fmf.host; spec: docs/HOST-MODEL.md, phase 4): how this hypervisor connects a
# guest interface in each zone. Every VM here is on the LAN; its taps join br-lan through the hand-written
# `30-lan-vm-taps` rule in ./default.nix (blue-ridge is the router host, so no generated tap rules).
# fleet checks that the two agree.
{...}: {
  fmf.host.hypervisor.networks.lan.bridge = "br-lan";
}
