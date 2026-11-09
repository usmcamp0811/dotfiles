# Storage and store layout for vm-vault (fmf.host; spec: docs/HOST-MODEL.md, Phase 3). Its shares and
# writable-store overlay come from this record (not ./default.nix), and blue-ridge's stanza, directories
# and start ordering for it are generated into network/generated/microvms.nix by `fleet`.
{...}: {
  fmf.host = {
    derive = true;
    nixStore = "persistent";
    # No guest here uses the hypervisor's root password hash (fmf.system.passwds is not enabled on VMs).
    standardShares.rootPassword = false;
    # Its data lives on a microvm volume image (see ./default.nix), so there is no storage share.
  };
}
