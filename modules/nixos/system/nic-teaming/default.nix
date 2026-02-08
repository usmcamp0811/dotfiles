{ options
, config
, pkgs
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.nic-teaming;
in
{
  options.fmf.system.nic-teaming = with types; {
    enable = mkBoolOpt false "Enable NIC Teaming";
    ip = mkOpt str "192.168.1.123" "IP to bind team to";
    bondNICs = mkOpt (lib.types.listOf lib.types.str) [ ] "The NICs to bond";
  };

  config = mkIf cfg.enable {
    systemd.services.network-team-setup = {
      description = "Network Teaming Setup";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";

      script = ''
        # Your shell commands here, adapted from your Ansible script
        ${pkgs.networkmanager}/bin/nmcli connection delete team0 || true

        NIC_LIST="${lib.concatStringsSep " " cfg.bondNICs}"

        ${pkgs.networkmanager}/bin/nmcli connection add type team con-name team0 ifname team0 config '{"runner": {"name": "loadbalance"}}'

        for nic in $NIC_LIST; do
          ${pkgs.networkmanager}/bin/nmcli connection delete team0-nic-$nic || true
          ${pkgs.networkmanager}/bin/nmcli connection add type team-slave con-name team0-nic-$nic ifname $nic master team0
        done

        ${pkgs.networkmanager}/bin/nmcli connection modify team0 ipv4.addresses ${cfg.ip}
        ${pkgs.networkmanager}/bin/nmcli connection modify team0 ipv4.method manual
        ${pkgs.networkmanager}/bin/nmcli connection up team0
      '';
    };

    environment.systemPackages = with pkgs; [ networkmanager ];
  };
}
