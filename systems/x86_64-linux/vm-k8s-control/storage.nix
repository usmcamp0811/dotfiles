# Storage and store layout for vm-k8s-control (fmf.host; spec: docs/HOST-MODEL.md, Phase 3). Its shares and
# writable-store overlay come from this record (not ./default.nix). The VM is standby and not placed on a
# hypervisor, so nothing is generated for a hypervisor until it is (placement.runsOn in ./host.nix).
{...}: {
  fmf.host = {
    derive = true;
    nixStore = "persistent";
    # No guest here uses the hypervisor's root password hash (fmf.system.passwds is not enabled on VMs).
    standardShares.rootPassword = false;
    storage = {
      k8s-data.mountPoint = "/var/lib/rancher"; # host: /persist/vm-data/vm-k8s-control/k8s-data
      longhorn-storage = {
        mountPoint = "/var/lib/longhorn";
        hostPath = "/persist/longhorn/vm-k8s-control";
      };
    };
  };
}
