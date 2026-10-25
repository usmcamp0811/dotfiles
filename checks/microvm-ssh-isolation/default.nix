{pkgs, lib, ...}:
pkgs.testers.nixosTest {
  name = "microvm-ssh-isolation";

  nodes.host = {lib, ...}: {
    imports = [../../modules/nixos/security/microvm-ssh-isolation];
    # Only interface metadata is needed: veth access ports emulate TAP ingress
    # without building a nested fleet. Exercise all three upstream resolvers,
    # including a declared guest which is not automatically started.
    options.microvm.vms = lib.mkOption { type = lib.types.attrs; default = {}; };
    config = let
      guest = id: {microvm.interfaces = [{type = "tap"; inherit id;}];};
    in {
      microvm.vms = {
        vm-vault.flake.nixosConfigurations.vm-vault.config = guest "tap-vault";
        vm-other = {autostart = false; evaluatedConfig.config = guest "tap-other";};
        vm-third.config.config = guest "tap-third";
      };
      fmf.security.microvm-ssh-isolation = {
        enable = true;
        sshPorts = [22 2222];
        exceptions = [{vm = "vm-vault"; destination = "10.8.0.1"; reason = "Vault recovery";}];
      };
      # Exercise composition with the effective NixOS nft firewall as well as
      # a separately managed inet table (the router uses that arrangement).
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [22 2222 8080];
      };
      networking.nftables.tables.existing_router = {
        family = "inet";
        content = "chain input { type filter hook input priority 0; policy accept; }";
      };
      environment.systemPackages = [pkgs.socat pkgs.iproute2 (pkgs.python3.withPackages (p: [p.scapy]))];
      systemd.services."microvm@vm-other".serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/true";
      };
    };
  };

  testScript = ''
    import json

    host.start()
    host.wait_for_unit("nftables.service")
    host.succeed("nft list table inet existing_router")
    host.succeed("ip link add br-test type bridge; ip link set br-test up")
    host.succeed("ip addr add 10.8.0.1/24 dev br-test; ip addr add 10.8.0.2/24 dev br-test; ip -6 addr add fd08::1/64 dev br-test")
    for name, number in [("vault", 3), ("other", 4), ("third", 5)]:
        host.succeed(f"ip netns add {name}; ip link add tap-{name} type veth peer name eth0 netns {name}")
        host.succeed(f"ip link set tap-{name} master br-test; ip link set tap-{name} up")
        host.succeed(f"ip -n {name} link set lo up; ip -n {name} link set eth0 up")
        host.succeed(f"ip -n {name} addr add 10.8.0.{number}/24 dev eth0; ip -n {name} -6 addr add fd08::{number}/64 dev eth0 nodad")
    host.succeed("socat TCP4-LISTEN:22,bind=10.8.0.1,reuseaddr,fork EXEC:cat >/dev/null 2>&1 &")
    host.succeed("socat TCP6-LISTEN:22,ipv6only=1,reuseaddr,fork EXEC:cat >/dev/null 2>&1 &")
    host.succeed("socat TCP4-LISTEN:2222,reuseaddr,fork EXEC:cat >/dev/null 2>&1 &")
    host.succeed("socat TCP4-LISTEN:8080,reuseaddr,fork EXEC:cat >/dev/null 2>&1 &")
    host.succeed("socat TCP6-LISTEN:8080,ipv6only=1,reuseaddr,fork EXEC:cat >/dev/null 2>&1 &")
    host.succeed("ip netns exec other socat TCP4-LISTEN:22,reuseaddr,fork EXEC:cat >/dev/null 2>&1 &")
    host.succeed("ip netns exec other socat TCP6-LISTEN:22,ipv6only=1,reuseaddr,fork EXEC:cat >/dev/null 2>&1 &")
    host.wait_until_succeeds("ss -lnt | grep ':8080 '")

    def connect(ns, address, port, allowed, source=None):
        family = "AF_INET6" if ":" in address else "AF_INET"
        program = f"import socket; s=socket.socket(socket.{family}); s.settimeout(2); "
        if source:
            program += f"s.bind(({source!r}, 0)); "
        program += f"s.connect(({address!r}, {port})); s.sendall(b'works'); assert s.recv(5) == b'works'"
        command = (f"ip netns exec {ns} " if ns else "") + "python -c " + __import__("shlex").quote(program)
        (host.succeed if allowed else host.fail)(command)

    with subtest("guest origins denied on every fleet SSH port; other services pass"):
        for ns in ["other", "third"]:
            connect(ns, "10.8.0.1", 22, False)
            connect(ns, "10.8.0.1", 2222, False)
            connect(ns, "fd08::1", 22, False)
            connect(ns, "10.8.0.1", 8080, True)
            connect(ns, "fd08::1", 8080, True)
        connect("third", "10.8.0.4", 22, False)

    with subtest("Vault exception belongs to its interface, not its IP"):
        connect("vault", "10.8.0.1", 22, True)
        connect("vault", "fd08::1", 22, False)
        connect("vault", "10.8.0.1", 2222, False)
        connect("vault", "10.8.0.4", 22, False)
        # Move Vault's address to the hostile guest for a complete spoofed
        # handshake attempt (avoids conflicting ARP and tests actual transport).
        host.succeed("ip -n vault addr del 10.8.0.3/24 dev eth0; ip -n other addr add 10.8.0.3/24 dev eth0")
        host.succeed("ip -6 -n other addr add fd08::3/64 dev eth0 nodad; ip neigh flush dev br-test")
        connect("other", "10.8.0.1", 22, False, "10.8.0.3")
        connect("other", "fd08::1", 22, False, "fd08::3")

    with subtest("host-initiated SSH and replies to source port 22 work"):
        connect(None, "10.8.0.4", 22, True)
        connect(None, "fd08::4", 22, True)
        # Guest reply dport is 22 here: an unconditional dport drop breaks it.
        host.succeed("ip netns exec other socat TCP4-LISTEN:8080,reuseaddr,fork EXEC:cat >/dev/null 2>&1 &")
        host.succeed("python -c \"import socket; s=socket.socket(); s.settimeout(3); s.bind(('10.8.0.2',22)); s.connect(('10.8.0.4',8080)); s.sendall(b'reply'); assert s.recv(5)==b'reply'\"")

    def drops():
        rules = json.loads(host.succeed("nft -j list chain bridge fmf_microvm_ssh_isolation guest_ingress"))
        return [expr["counter"]["packets"] for entry in rules["nftables"] if "rule" in entry
                for expr in entry["rule"]["expr"] if "counter" in expr and any("drop" in e for e in entry["rule"]["expr"])]

    with subtest("tagged and fragmented packets cannot bypass guest policy"):
        # Raw Ethernet to bridge MAC, no ARP ambiguity. Each fragmented SYN
        # must be reassembled and counted at the SSH drop rule.
        mac = host.succeed("cat /sys/class/net/br-test/address").strip()
        packets = [
            (0, "[Dot1Q(vlan=10)/IP(src='10.8.0.3',dst='10.8.0.1')/TCP(dport=22,flags='S')]"),
            (0, "[Dot1AD(vlan=10)/Dot1Q(vlan=20)/IP(src='10.8.0.3',dst='10.8.0.1')/TCP(dport=22,flags='S')]"),
            (1, "fragment(IP(src='10.8.0.3',dst='10.8.0.1',id=1234)/TCP(sport=33001,dport=22,flags='S')/Raw(b'x'*64),fragsize=24)"),
            (1, "fragment6(IPv6(src='fd08::3',dst='fd08::1')/IPv6ExtHdrFragment(id=4321)/TCP(sport=33002,dport=22,flags='S')/Raw(b'x'*64),72)"),
            (1, "[IPv6(src='fd08::3',dst='fd08::1')/IPv6ExtHdrDestOpt()/TCP(sport=33003,dport=22,flags='S')]")
        ]
        for counter, expression in packets:
            before = drops()[counter]
            script = f"from scapy.all import *; packets={expression}; sendp([Ether(dst={mac!r})/p for p in packets],iface='eth0',verbose=False)"
            host.succeed("ip netns exec other python -c " + __import__("shlex").quote(script))
            assert drops()[counter] > before, expression

    with subtest("declared non-autostart VM requires a successful initial nft load"):
        host.succeed("systemctl start microvm@vm-other.service")
        host.succeed("systemctl stop microvm@vm-other.service nftables.service")
        host.succeed("mkdir -p /run/systemd/system/nftables.service.d")
        host.succeed("printf '[Service]\\nExecStart=\\nExecStart=/run/current-system/sw/bin/false\\n' > /run/systemd/system/nftables.service.d/fail.conf")
        host.succeed("systemctl daemon-reload")
        host.fail("systemctl start microvm@vm-other.service")
        host.fail("systemctl is-active microvm@vm-other.service")
  '';
}
