{ callPackage, ... }:
callPackage ../wazuh/mk-wazuh.nix {
  pname = "wazuh-agent";
  target = "agent";
  installType = "agent";
}
