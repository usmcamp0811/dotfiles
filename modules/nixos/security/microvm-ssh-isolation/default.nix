{
  config,
  lib,
  pkgs,
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
  docker = config.virtualisation.docker;
  dockerOptions = lib.replaceStrings ["\n" "\t"] [" " " "] docker.extraOptions;
  dockerHasOption = pattern: builtins.match ".*--${pattern}( .*|$)" dockerOptions != null;
  dockerBridgeRules = pkgs.writeText "microvm-docker-bridges.rules" ''
    :FMF-MICROVM-BRIDGES - [0:0]
    -F FMF-MICROVM-BRIDGES
    ${lib.concatMapStringsSep "\n" (bridge:
      "-A FMF-MICROVM-BRIDGES -i ${bridge} -o ${bridge} -j ACCEPT"
    ) (lib.unique cfg.dockerBridgeInterfaces)}
  '';
  dockerBridgeScript = pkgs.writeShellScript "microvm-docker-bridges" ''
    set -euo pipefail
    for family in iptables ip6tables; do
      # Use the same pkgs.iptables tools as the Docker package. With IPv6
      # disabled Docker may not have created DOCKER-USER yet. Declaring it
      # below is harmless: we never link it from FORWARD ourselves.
      deletes=""
      createDockerUser=""
      if rules=$("${pkgs.iptables}/bin/$family" -w -t filter -S DOCKER-USER 2>/dev/null); then
        while IFS= read -r rule; do
          if [[ "$rule" == "-A DOCKER-USER -j FMF-MICROVM-BRIDGES" ]]; then
            deletes+=$'-D DOCKER-USER -j FMF-MICROVM-BRIDGES\n'
          fi
        done <<< "$rules"
      else
        createDockerUser=":DOCKER-USER - [0:0]"
      fi
      # --noflush preserves Docker and third-party rules. Only our chain is
      # flushed, removing stale bridges; moving our jump to first position
      # happens in the same per-family transaction as the chain rebuild.
      # Never redeclare an existing DOCKER-USER: even with --noflush, a
      # user-chain declaration can flush that chain on iptables backends.
      "${pkgs.iptables}/bin/$family-restore" --wait --noflush <<EOF
    *filter
    $createDockerUser
    $(< ${dockerBridgeRules})
    $deletes
    -I DOCKER-USER 1 -j FMF-MICROVM-BRIDGES
    COMMIT
    EOF
    done
  '';
  nftSet = values: "{ ${lib.concatStringsSep ", " values} }";
  names = values: nftSet (map builtins.toJSON values);
  ports = values: nftSet (map toString values);
  exceptions = lib.concatMapStringsSep "\n" (exception:
    lib.optionalString ((taps.${exception.vm} or []) != []) ''
      iifname ${names taps.${exception.vm}} ${if exception.family == "ip" then "ip" else "ip6"} daddr ${exception.destination} meta l4proto tcp tcp dport ${ports exception.ports} counter return comment ${builtins.toJSON exception.reason}
    '') cfg.exceptions;
  nftables = config.networking.nftables;
  guard = if nftables.enable then "nftables" else "microvm-ssh-isolation";
  tableContent = ''
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
  # `add` tolerates an existing table. Flush and rebuild only our table in a
  # single transaction, so a failed load leaves the previous guard intact.
  guardRules = pkgs.writeText "microvm-ssh-isolation.nft" ''
    add table bridge fmf_microvm_ssh_isolation
    flush table bridge fmf_microvm_ssh_isolation
    table bridge fmf_microvm_ssh_isolation {
      ${tableContent}
    }
  '';
in {
  options.fmf.security.microvm-ssh-isolation = {
    enable = lib.mkEnableOption "bridge-ingress MicroVM SSH isolation";
    sshPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [22];
      description = "Fleet SSH destination ports blocked for guest-originated TCP, including guest-to-guest and external traffic.";
    };
    dockerBridgeInterfaces = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,14}");
      default = [];
      description = ''
        Exact Linux bridge names whose same-bridge traffic is accepted before
        Docker's forwarding rules, for IPv4 and IPv6. Wildcards are forbidden;
        names must be 1–15 characters. Requires local guest TAPs and Docker's
        iptables firewall backend with iptables enabled (the native Docker
        nftables backend is unsupported). The bridge-ingress SSH guard still
        applies. An empty list disables this Docker integration.
      '';
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
      # Older stateVersions default to flushing the entire ruleset on reload,
      # which destroys Docker's dynamically managed NAT/filter tables. When
      # using named tables, replace only NixOS-owned tables instead. Leave
      # legacy complete rulesets (e.g. routers) under their owner's control.
      networking.nftables.flushRuleset = lib.mkIf (
        nftables.enable && nftables.ruleset == ""
        && nftables.rulesetFile == null
      ) false;
      # A separate bridge table composes with the router's inet ruleset and
      # NixOS' nft firewall. Do not replace either of those rulesets.
      networking.nftables.tables = lib.mkIf nftables.enable { fmf_microvm_ssh_isolation = {
        family = "bridge";
        content = tableContent;
      }; };
      systemd.services = lib.mapAttrs' (name: _: lib.nameValuePair "microvm@${name}" {
        requires = ["${guard}.service"];
        after = ["${guard}.service"];
      }) vms // {
        nftables = lib.mkIf nftables.enable {
          after = ["systemd-modules-load.service"];
        };
        microvm-ssh-isolation = lib.mkIf (!nftables.enable) {
          description = "MicroVM bridge SSH isolation (independent of host firewall)";
          wantedBy = ["multi-user.target"];
          after = ["systemd-modules-load.service"];
          reloadIfChanged = true;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.nftables}/bin/nft -f ${guardRules}";
            ExecReload = "${pkgs.nftables}/bin/nft -f ${guardRules}";
            # Deliberately no ExecStop: stopping must leave guests protected.
          };
        };
      };
    })
    (lib.mkIf (allTaps != [] && docker.enable && cfg.dockerBridgeInterfaces != []) {
      assertions = [
        {
          assertion = (docker.daemon.settings.iptables or true) != false
            && !(dockerHasOption "iptables(=| +)false");
          message = "MicroVM Docker bridge exceptions require virtualisation.docker.daemon.settings.iptables to be enabled.";
        }
        {
          assertion = (docker.daemon.settings."firewall-backend" or "iptables") == "iptables"
            && !(dockerHasOption "firewall-backend(=| +)nftables");
          message = "MicroVM Docker bridge exceptions require Docker's iptables backend; the native Docker nftables backend is unsupported.";
        }
      ];
      # Docker is Type=notify: postStart runs after daemon initialization and
      # on every restart, composing with any existing postStart hooks.
      systemd.services.docker.postStart = lib.mkAfter ''
        ${dockerBridgeScript}
      '';
    })
  ]);
}
