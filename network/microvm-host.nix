# What a hypervisor derives from the host records of the MicroVMs it runs: each VM's `microvm.vms`
# stanza, its host directories and its start ordering, read from network/generated/microvms.nix
# (written by `fleet`). Only VMs that set `fmf.host.derive` appear there, so a host that runs none has no
# entry and this module does nothing. Loaded for every system by flake.nix.
#
# Tap-to-bridge rules (hypervisor.tapRules) are not generated here: blue-ridge is the router host and keeps
# its hand-written `30-lan-vm-taps` rule.
#
# The VM's `flake` is the one thing the file cannot hold, so it is added here.
{
  config,
  lib,
  inputs,
  ...
}: let
  mine = (import ./generated/microvms.nix).${config.networking.hostName} or null;
in {
  config = lib.mkIf (mine != null) {
    microvm.vms = lib.mapAttrs (_: vm:
      vm
      // {
        flake = inputs.self;
        updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
      })
    mine.vms;
    systemd.tmpfiles.rules = mine.tmpfiles;
    systemd.services = mine.units;
  };
}
