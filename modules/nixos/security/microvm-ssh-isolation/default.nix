{
  config,
  lib,
  ...
}: let
  cfg = config.fmf.security.microvm-ssh-isolation;
  vms = config.microvm.vms or {};
  guestConfig = name: vm:
    if (vm.flake or null) != null
    then vm.flake.nixosConfigurations.${name}.config
    else if (vm.evaluatedConfig or null) != null
    then vm.evaluatedConfig.config
    else vm.config.config;
  interfaces = lib.mapAttrs (name: vm: (guestConfig name vm).microvm.interfaces) vms;
  taps = lib.mapAttrs (_: ifaces: map (iface: iface.id) (builtins.filter (iface: iface.type == "tap") ifaces)) interfaces;
  allTaps = lib.unique (lib.concatLists (builtins.attrValues taps));
  nftSet = values: "{ ${lib.concatStringsSep ", " values} }";
  names = values: nftSet (map builtins.toJSON values);
  ports = values: nftSet (map toString values);
  exceptions = lib.concatMapStringsSep "\n" (exception:
    lib.optionalString ((taps.${exception.vm} or []) != []) ''
      iifname ${names taps.${exception.vm}} ${if exception.family == "ip" then "ip" else "ip6"} daddr ${exception.destination} meta l4proto tcp tcp dport ${ports exception.ports} counter return comment ${builtins.toJSON exception.reason}
    '') cfg.exceptions;
in {
  options.fmf.security.microvm-ssh-isolation = {
    enable = lib.mkEnableOption "bridge-ingress MicroVM SSH isolation";
    sshPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [22];
      description = "Fleet SSH destination ports blocked for guest-originated TCP, including guest-to-guest and external traffic.";
    };
    exceptions = lib.mkOption {
      default = [];
      description = "Audited SSH exceptions bound to a declared guest's TAPs, never to its spoofable source address.";
      type = lib.types.listOf (lib.types.submodule {
        options = {
          vm = lib.mkOption { type = lib.types.str; };
          family = lib.mkOption { type = lib.types.enum ["ip" "ip6"]; default = "ip"; };
          destination = lib.mkOption {
            type = lib.types.strMatching "[0-9a-fA-F.:]+";
            description = "Literal destination address (no subnet or nft expression).";
          };
          ports = lib.mkOption { type = lib.types.listOf lib.types.port; default = [22]; };
          reason = lib.mkOption { type = lib.types.nonEmptyStr; };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = lib.mapAttrsToList (name: ifaces: {
        assertion = lib.all (iface: iface.type == "tap") ifaces;
        message = "MicroVM SSH isolation: ${name} has a non-TAP interface; bridge ingress cannot protect it. Convert the interface before enabling isolation.";
      }) interfaces ++ [
        {
          assertion = lib.all (exception: builtins.hasAttr exception.vm vms && exception.ports != []) cfg.exceptions;
          message = "MicroVM SSH isolation exceptions require a declared VM and nonempty ports.";
        }
        {
          assertion = cfg.sshPorts != [];
          message = "MicroVM SSH isolation requires at least one fleet SSH port.";
        }
        {
          assertion = builtins.length (lib.concatLists (builtins.attrValues taps)) == builtins.length allTaps;
          message = "MicroVM SSH isolation requires unique guest TAP names (exceptions must identify exactly one guest).";
        }
      ];
    }
    (lib.mkIf (allTaps != []) {
      boot.kernelModules = ["nf_conntrack_bridge"];
      networking.nftables.enable = true;
      # A separate bridge table composes with the router's inet ruleset and
      # NixOS' nft firewall. Do not replace either of those rulesets.
      networking.nftables.tables.fmf_microvm_ssh_isolation = {
        family = "bridge";
        content = ''
          chain guest_ingress {
            # Access ports only: reject single and stacked guest VLAN tags.
            ether type { 0x8100, 0x88a8 } counter drop
            # Only replies, not arbitrary established guest-originated flows.
            ct state established ct direction reply counter return
            ${exceptions}
            meta l4proto tcp tcp dport ${ports cfg.sshPorts} counter drop
          }
          chain prerouting {
            # Bridge conntrack/defragmentation runs at -200. Match L4 after it,
            # including IPv6 extension headers and reassembled IP fragments.
            type filter hook prerouting priority -150; policy accept;
            iifname ${names allTaps} jump guest_ingress
          }
        '';
      };
      systemd.services = lib.mapAttrs' (name: _: lib.nameValuePair "microvm@${name}" {
        requires = ["nftables.service"];
        after = ["nftables.service"];
      }) vms // {
        nftables.after = ["systemd-modules-load.service"];
      };
    })
  ]);
}
