{
  config,
  lib,
  inputs ? {},
  ...
}: let
  cfg = config.fmf.suites.microvm-host;
  physicalHosts = lib.filterAttrs
    (name: _: !(lib.hasPrefix "vm-" name))
    (inputs.self.nixosConfigurations or {});
in {
  options.fmf.suites.microvm-host.enable =
    lib.mkEnableOption "MicroVM host SSH isolation policy";

  config = lib.mkIf cfg.enable {
    fmf.security.microvm-ssh-isolation = {
      enable = true;
      sshPorts = lib.unique ([22] ++ config.services.openssh.ports ++ lib.concatMap
        (host: host.config.services.openssh.ports)
        (lib.attrValues physicalHosts));
    };
  };
}
