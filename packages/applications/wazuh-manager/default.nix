{ callPackage, ... }:
callPackage ../wazuh/mk-wazuh.nix {
  pname = "wazuh-manager";
  target = "server";
  installType = "server";
}
