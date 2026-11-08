# Regression tests for lib.fmf.fleet; no host evaluation needed.
#   nix-instantiate --eval --strict lib/fleet/tests.nix --arg pkgs 'import <nixpkgs> {}'   # -> "ok"; failures throw
{pkgs ? import <nixpkgs> {}}: let
  lib = pkgs.lib;
  f = (import ./default.nix {inherit lib;}).fleet;

  # ---- builders: fill in the module defaults so a test only states what it cares about ----
  iface = a:
    {
      mac = null;
      ip = null;
      zone = "lan";
      attach = "tap";
      static = false;
      primary = null;
      leaseName = null;
    }
    // a;
  host = name: a:
    lib.recursiveUpdate {
      inherit name;
      managed = true;
      kind = "physical";
      lifecycle = "active";
      retired = {since = null; reason = null; replacedBy = null;};
      interfaces = {};
      placement = {runsOn = null; autostart = true; restartIfChanged = null; hostDirectories = "managed";};
      nixStore = "persistent";
      standardShares = {rootPassword = true; vaultAgent = null;};
      storage = {};
      boot = {after = []; hostUnits = [];};
      dns = {names = []; addAliases = true;};
      expose = [];
      vault = {role = null; extraPolicies = []; aliases = [];};
      topology = {role = null; location = null; rack = null; tags = [];};
      vaultAgent = false;
      vaultServer = false;
    } a;
  vm = name: runsOn: a:
    host name (lib.recursiveUpdate {kind = "microvm"; placement.runsOn = runsOn;} a);
  store = a: {tag = null; hostPath = null; mode = "0755"; owner = "root"; group = "root"; createDirectory = true; readOnly = false; shared = false; mountPoint = "/x"; order = 100;} // a;
  exposeE = a: {destPort = null; proto = "tcp"; description = "";} // a;

  zones = {
    lan = {subnet = "192.168.50.0/24"; gateway = "192.168.50.1"; vlanId = null; dns = []; hostDomain = "lan-hosts.example.com"; description = ""; dhcpRange = {start = "192.168.50.50"; end = "192.168.50.200";};};
    wifi = {subnet = "192.168.51.0/24"; gateway = "192.168.51.1"; vlanId = 10; dns = []; hostDomain = null; description = "";};
  };

  hosts = lib.listToAttrs (map (h: lib.nameValuePair h.name h) [
    (host "blue-ridge" {interfaces.lan = iface {mac = "aa:00:00:00:00:01"; ip = "192.168.50.1";}; topology = {role = "router"; location = null; rack = null; tags = ["core"];};})
    (host "chesty" {interfaces.lan = iface {mac = "aa:00:00:00:00:02"; ip = "192.168.50.114";};})
    (host "lucas" {
      interfaces = {
        eth = iface {mac = "aa:00:00:00:00:03"; ip = "192.168.50.188"; primary = true;};
        wifi = iface {mac = "aa:00:00:00:00:04"; ip = "192.168.51.7"; zone = "wifi";};
      };
    })
    (host "edson" {
      lifecycle = "retired";
      interfaces.lan = iface {mac = "aa:00:00:00:00:05"; ip = "192.168.50.20";};
      vault.role = "edson";
    })
    (vm "vm-vault" "blue-ridge" {
      interfaces.lan = iface {mac = "02:00:00:00:00:10"; ip = "192.168.50.3"; static = true;};
      vaultAgent = true;
      vaultServer = true;
      boot.hostUnits = ["tang.socket"];
    })
    (vm "vm-gitea" "blue-ridge" {
      interfaces.lan = iface {mac = "02:00:00:00:00:40"; ip = "192.168.50.6";};
      vaultAgent = true;
      boot.after = ["vm-vault"];
      placement = {runsOn = "blue-ridge"; autostart = true; restartIfChanged = true;};
      storage.data = store {mountPoint = "/var/lib/gitea";};
    })
    (vm "vm-lan-traefik" "blue-ridge" {
      interfaces.lan = iface {mac = "02:00:00:00:00:21"; ip = "192.168.50.4";};
      vault.aliases = ["lan-traefik"];
      dns.names = ["vault.lan.example.com"];
    })
    (vm "vm-topology" "blue-ridge" {
      lifecycle = "standby";
      interfaces.lan = iface {mac = "02:00:00:00:00:99"; ip = "192.168.50.9";};
      expose = [(exposeE {port = 9999;})];
    })
    (vm "vm-mattermost" "lucas" {
      interfaces.lan = iface {mac = "02:00:00:00:00:b0"; ip = "192.168.50.16";};
      expose = [(exposeE {port = 8443; proto = "udp"; description = "Calls";}) (exposeE {port = 8443; description = "Calls";})];
      vaultAgent = true;
      storage = {
        mattermost = store {mountPoint = "/var/lib/mattermost";};
        postgresql = store {mountPoint = "/var/lib/postgresql"; tag = "pg"; hostPath = "/persist/pg/mm"; mode = "0700";};
      };
    })
    # takes over the address of retired edson: must NOT be reported as a duplicate
    (vm "vm-pub-traefik" "chesty" {interfaces.lan = iface {mac = "02:00:00:00:00:20"; ip = "192.168.50.20";};})
    {name = "some-unmanaged"; managed = false;}
  ]);

  r = f.mk {inherit hosts zones;};

  # devices: leases of things that are not hosts. Note the mixed-case name, as in real lease files.
  devices = [
    {zone = "lan"; mac = "AA:11:00:00:00:01"; ip = "192.168.50.200"; hostname = "Campnet-AP";}
    {zone = "wifi"; mac = "aa:11:00:00:00:02"; ip = "192.168.51.50"; hostname = "printer";}
  ];
  rd = f.mk {inherit hosts zones; deviceLeases = devices;};
  files = f.render rd;
  withDev = extra: (f.mk {hosts = hosts; inherit zones; deviceLeases = devices ++ extra;});
  devErrs = extra: msgs (withDev extra).errors;
  devWarns = extra: msgs (withDev extra).warnings;
  msgs = x: map (e: e.message) x;
  has = sub: xs: lib.any (m: lib.hasInfix sub m) xs;
  # one MicroVM `vm-s` on lucas with the given overrides: its shares, store overlay and the directories lucas creates for it
  shapeOf = a: let
    res = (f.mk {hosts = add [(vm "vm-s" "lucas" a)]; inherit zones;}).hypervisors.lucas;
    mine = lib.filter (l: lib.hasInfix "/vm-s " l || lib.hasInfix "/vm-s/" l) res.tmpfiles;
  in {
    shares = res.shares."vm-s";
    overlay = res.overlays."vm-s";
    tmpfiles = mine ++ lib.filter (l: lib.hasInfix "/persist/system/secrets" l) res.tmpfiles;
  };
  tagsOf = x: map (s: s.tag) x.shares;
  hv' = (f.mk {hosts = add [(vm "vm-s" "lucas" {vaultAgent = true; storage.data = store {};})]; inherit zones;}).hypervisors;
  errsOf = hs: msgs (f.mk {hosts = hs; inherit zones;}).errors;
  warnsOf = hs: msgs (f.mk {hosts = hs; inherit zones;}).warnings;
  add = extra: hosts // lib.listToAttrs (map (h: lib.nameValuePair h.name h) extra);
  with' = name: patch: {${name} = hosts.${name} // patch;};

  hv = r.hypervisors;

  checks = [
    # ---- partition ----
    ["partition" (r.hosts.active == ["blue-ridge" "chesty" "lucas" "vm-gitea" "vm-lan-traefik" "vm-mattermost" "vm-pub-traefik" "vm-vault"]
      && r.hosts.standby == ["vm-topology"] && r.hosts.retired == ["edson"] && r.hosts.unmanaged == ["some-unmanaged"])]
    ["clean fleet has no errors" (r.errors == [])]

    # ---- leases: per zone, sorted by address, lease name without vm-, retired absent ----
    ["leases by zone" (lib.attrNames r.leases == ["lan" "wifi"])]
    ["lease name drops vm-" (lib.any (l: l.hostname == "vault" && l.ip == "192.168.50.3") r.leases.lan)]
    ["lease sorted by ip" (map (l: l.ip) r.leases.lan == ["192.168.50.1" "192.168.50.3" "192.168.50.4" "192.168.50.6" "192.168.50.9" "192.168.50.16" "192.168.50.20" "192.168.50.114" "192.168.50.188"])]
    ["non-primary interface gets suffix" (r.leases.wifi == [{ip = "192.168.51.7"; mac = "aa:00:00:00:00:04"; hostname = "lucas-wifi";}])]
    ["retired host has no lease" (!(lib.any (l: l.hostname == "edson") r.leases.lan))]
    ["address goes to the new owner" (lib.any (l: l.ip == "192.168.50.20" && l.hostname == "pub-traefik") r.leases.lan)]

    # ---- DNS ----
    ["dns short and host fqdn" (r.dns.vault == "192.168.50.3" && r.dns."vm-vault" == "192.168.50.3" && r.dns."vault.lan-hosts.example.com" == "192.168.50.3")]
["service name is a separate namespace" (r.dns."vault.lan.example.com" == "192.168.50.4" && r.dns."vault.lan-hosts.example.com" != r.dns."vault.lan.example.com")]
    ["dns fqdn from zone hostDomain" (r.dns."gitea.lan-hosts.example.com" == "192.168.50.6" && r.dns."vm-gitea.lan-hosts.example.com" == "192.168.50.6")]
        ["dns for second interface" (r.dns."lucas-wifi" == "192.168.51.7" && r.dns.lucas == "192.168.50.188")]
    ["no dns for retired" (!(r.dns ? edson))]
    ["zone without domain gets no fqdn" (!(lib.any (n: lib.hasSuffix ".null" n) (lib.attrNames r.dns)))]

    # ---- forwards: active only, to the primary address ----
    ["forwards" (map (x: [x.port x.protocol x.destination]) r.forwards == [[8443 "udp" "192.168.50.16"] [8443 "tcp" "192.168.50.16"]])]
    ["standby expose ignored" (!(lib.any (x: x.port == 9999) r.forwards))]

    # ---- Vault ----
    ["role defaults to host name" (r.vault.roles ? "vm-mattermost" && r.vault.roles."vm-mattermost".aliasOf == null)]
    ["alias is a role with the same host" (r.vault.roles."lan-traefik" == {host = "vm-lan-traefik"; extraPolicies = []; aliasOf = "vm-lan-traefik";})]
    ["alias shares expected ips" (r.vault.expectedIps."lan-traefik" == ["192.168.50.4"] && r.vault.expectedIps."vm-lan-traefik" == ["192.168.50.4"])]
    ["expected ips union over interfaces" (r.vault.expectedIps.lucas == ["192.168.50.188" "192.168.51.7"])]
    ["retired role reported, not provisioned" (r.vault.retiredRoles == ["edson"] && !(r.vault.roles ? edson) && !(r.vault.expectedIps ? edson))]

    # ---- hypervisors: only guests of that host; derived directories, shares, units ----
    ["hypervisors" (lib.attrNames hv == ["blue-ridge" "chesty" "lucas"])]
    ["vms of a hypervisor" (lib.attrNames hv.blue-ridge.vms == ["vm-gitea" "vm-lan-traefik" "vm-topology" "vm-vault"])]
    ["standby does not autostart" (hv.blue-ridge.vms.vm-topology.autostart == false && hv.blue-ridge.vms.vm-vault.autostart == true)]
    ["restartIfChanged null is not emitted" (!(hv.blue-ridge.vms.vm-vault ? restartIfChanged) && hv.blue-ridge.vms.vm-gitea.restartIfChanged == true)]
    ["vault dir only for vault-agent guests" (lib.elem "d /persist/system/var/lib/vault/vm-gitea 0700 root root -" hv.blue-ridge.tmpfiles
      && !(lib.elem "d /persist/system/var/lib/vault/vm-lan-traefik 0700 root root -" hv.blue-ridge.tmpfiles))]
    ["storage default path and mode" (lib.elem "d /persist/vm-data/vm-gitea/data 0755 root root -" hv.blue-ridge.tmpfiles)]
    ["storage explicit path and mode" (lib.elem "d /persist/pg/mm 0700 root root -" hv.lucas.tmpfiles)]
    ["ssh dir is 0700" (lib.elem "d /persist/vm-data/vm-gitea/ssh 0700 root root -" hv.blue-ridge.tmpfiles)]
    ["share order: standard then storage" (map (s: s.tag) hv.lucas.shares."vm-mattermost" == ["ro-store" "rw-store" "vault-agent" "ssh-host-keys" "root-password" "mattermost" "pg"])]
    ["explicit storage order beats the name" (map (s: s.tag) (f.mk {hosts = add [(vm "vm-o" "lucas" {storage = {aaa = store {order = 2;}; zzz = store {order = 1;}; mmm = store {order = 2;};};})]; inherit zones;}).hypervisors.lucas.shares."vm-o" == ["ro-store" "rw-store" "ssh-host-keys" "root-password" "zzz" "aaa" "mmm"])]
    ["no vault-agent share without vault-agent" (!(lib.any (s: s.tag == "vault-agent") hv.blue-ridge.shares."vm-lan-traefik"))]

    # ---- the variations found in the real fleet: store mode, root password, vault share, owners ----
    ["persistent store: rw-store share, overlay and both directories"
      (let x = shapeOf {}; in tagsOf x == ["ro-store" "rw-store" "ssh-host-keys" "root-password"] && x.overlay == "/nix/.rw-store"
        && lib.elem "d /persist/vm-stores/vm-s 0755 root root -" x.tmpfiles && lib.elem "d /persist/vm-stores/vm-s/nix-store 0755 root root -" x.tmpfiles)]
    ["volatile store: overlay set, no rw-store share, no store directory"
      (let x = shapeOf {nixStore = "volatile";}; in tagsOf x == ["ro-store" "ssh-host-keys" "root-password"] && x.overlay == "/nix/.rw-store"
        && !(lib.any (lib.hasInfix "vm-stores") x.tmpfiles))]
    ["no store overlay: neither share, overlay nor directory"
      (let x = shapeOf {nixStore = "none";}; in tagsOf x == ["ro-store" "ssh-host-keys" "root-password"] && x.overlay == null
        && !(lib.any (lib.hasInfix "vm-stores") x.tmpfiles))]
    ["root password share can be left out" (tagsOf (shapeOf {standardShares.rootPassword = false;}) == ["ro-store" "rw-store" "ssh-host-keys"])]
    ["vault share follows the agent" (lib.elem "vault-agent" (tagsOf (shapeOf {vaultAgent = true;})) && !(lib.elem "vault-agent" (tagsOf (shapeOf {}))))]
    ["vault share can be forced on without the agent" (lib.elem "vault-agent" (tagsOf (shapeOf {standardShares.vaultAgent = true;})))]
    ["vault share can be forced off with the agent" (!(lib.elem "vault-agent" (tagsOf (shapeOf {vaultAgent = true; standardShares.vaultAgent = false;}))))]
    ["vault directory follows the vault share"
      (lib.elem "d /persist/system/var/lib/vault/vm-s 0700 root root -" (shapeOf {standardShares.vaultAgent = true;}).tmpfiles)]
    ["standard order: ro, rw, vault, ssh, root, then storage"
      (tagsOf (shapeOf {vaultAgent = true; storage.data = store {};}) == ["ro-store" "rw-store" "vault-agent" "ssh-host-keys" "root-password" "data"])]
    ["storage owner and group reach tmpfiles" (lib.elem "d /persist/vm-data/vm-s/data 0700 10000 10000 -" (shapeOf {storage.data = store {mode = "0700"; owner = "10000"; group = "10000";};}).tmpfiles)]
    ["a storage entry can opt out of its directory" (let x = shapeOf {storage = {keep = store {}; skip = store {createDirectory = false;};};}; in lib.elem "d /persist/vm-data/vm-s/keep 0755 root root -" x.tmpfiles && !(lib.any (lib.hasInfix "/skip") x.tmpfiles) && lib.elem "skip" (tagsOf x))]
    ["external directories generate nothing" ((shapeOf {placement.hostDirectories = "external";}).tmpfiles == [])]
    ["external directories keep the shares" (tagsOf (shapeOf {placement.hostDirectories = "external";}) == ["ro-store" "rw-store" "ssh-host-keys" "root-password"])]
    ["the shared secrets directory is never generated" (!(lib.any (lib.hasInfix "/persist/system/secrets") (shapeOf {}).tmpfiles))]
    ["a guest computes its own shares the same way the hypervisor does"
      (let h = vm "vm-s" "lucas" {vaultAgent = true; storage.data = store {};}; in f.sharesOf h == hv'.lucas.shares."vm-s" && f.overlayOf h == hv'.lucas.overlays."vm-s")]
    ["share source and mount" (lib.any (s: s.tag == "pg" && s.source == "/persist/pg/mm" && s.mountPoint == "/var/lib/postgresql") hv.lucas.shares."vm-mattermost")]
    ["ordering units" (hv.blue-ridge.units."microvm@vm-gitea" == {after = ["microvm@vm-vault.service"]; wants = ["microvm@vm-vault.service"];})]
    ["host unit ordering (tang)" (hv.blue-ridge.units."microvm@vm-vault".after == ["tang.socket"])]
    ["no unit when nothing to order" (!(hv.blue-ridge.units ? "microvm@vm-lan-traefik"))]

    # ---- topology ----
    ["topology drops empties" (r.topology.blue-ridge == {role = "router"; tags = ["core"];} && r.topology.chesty == {})]

    # ---- assertions: each must fire on a deliberately broken fleet ----
    ["dup ip" (has "address 192.168.50.16 is used by" (errsOf (add [(host "dup" {interfaces.lan = iface {mac = "aa:00:00:00:00:77"; ip = "192.168.50.16";};})])))]
    ["dup mac" (has "MAC aa:00:00:00:00:01" (errsOf (add [(host "dup" {interfaces.lan = iface {mac = "AA:00:00:00:00:01"; ip = "192.168.50.77";};})])))]
    ["outside subnet" (has "outside zone `lan`" (errsOf (add [(host "far" {interfaces.lan = iface {mac = "aa:00:00:00:00:78"; ip = "192.168.99.5";};})])))]
    ["unknown zone" (has "unknown zone `nope`" (errsOf (add [(host "z" {interfaces.x = iface {zone = "nope";};})])))]
    ["bad ip" (has "not an IPv4 address" (errsOf (add [(host "b" {interfaces.x = iface {ip = "192.168.50";};})])))]
    ["active vm without runsOn" (has "needs placement.runsOn" (errsOf (add [(host "vm-x" {kind = "microvm";})])))]
    ["standby vm may be unplaced" (!(has "needs placement.runsOn" (errsOf (add [(host "vm-x" {kind = "microvm"; lifecycle = "standby";})]))))]
    ["runsOn not physical" (has "is not a physical host" (errsOf (add [(vm "vm-y" "vm-vault" {})])))]
    ["runsOn unknown" (has "not a host managed by the model" (errsOf (add [(vm "vm-y" "ghost" {})])))]
    ["runsOn retired" (has "is retired" (errsOf (add [(vm "vm-y" "edson" {})])))]
    ["after across machines" (has "ordering across machines is not possible" (errsOf (add [(vm "vm-z" "lucas" {boot.after = ["vm-vault"];})])))]
    ["after unknown" (has "not a managed host" (errsOf (add [(vm "vm-z" "lucas" {boot.after = ["ghost"];})])))]
    ["after itself" (has "lists itself" (errsOf (add [(vm "vm-z" "lucas" {boot.after = ["vm-z"];})])))]
    ["after a physical host" (has "is not a MicroVM" (errsOf (add [(vm "vm-z" "lucas" {boot.after = ["lucas"];})])))]
    ["boot cycle" (has "forms a cycle" (errsOf (add [(vm "vm-a" "lucas" {boot.after = ["vm-b"];}) (vm "vm-b" "lucas" {boot.after = ["vm-a"];})])))]
    ["no false cycle on a chain" (!(has "forms a cycle" (errsOf (add [(vm "vm-a" "lucas" {boot.after = ["vm-b"];}) (vm "vm-b" "lucas" {boot.after = ["vm-c"];}) (vm "vm-c" "lucas" {})]))))]
    ["retired referenced" (has "refers to retired host `edson`" (errsOf (add [(vm "vm-y" "edson" {})])))]
    ["storage collision" (has "not marked shared" (errsOf (add [(vm "vm-q" "lucas" {storage.m = store {hostPath = "/persist/pg/mm";};})])))]
    ["storage shared ok" (!(has "not marked shared" (errsOf (add [
      (vm "vm-q" "lucas" {storage.m = store {hostPath = "/persist/b"; shared = true;};})
      (vm "vm-r" "lucas" {storage.m = store {hostPath = "/persist/b"; shared = true;};})]))))]
    ["role collision" (has "Vault role `vm-vault` is claimed" (errsOf (add [(host "x" {vault.role = "vm-vault";})])))]
    ["alias collision" (has "Vault role `lan-traefik` is claimed" (errsOf (add [(host "x" {vault.aliases = ["lan-traefik"];})])))]
    ["dns conflict" (has "resolves to different addresses" (errsOf (add [(host "x" {interfaces.lan = iface {mac = "aa:00:00:00:00:79"; ip = "192.168.50.79";}; dns.names = ["vault.lan-hosts.example.com"];})])))]
    ["two primaries" (has "more than one interface is marked primary" (errsOf (add [(host "x" {interfaces = {a = iface {primary = true;}; b = iface {primary = true;};};})])))]
    ["many interfaces, no primary" (has "none is marked primary" (errsOf (add [(host "x" {interfaces = {a = iface {}; b = iface {};};})])))]
    ["non-local vm mac is a warning, not an error" (has "locally administered" (warnsOf (add [(vm "vm-w" "lucas" {interfaces.lan = iface {mac = "a8:00:00:00:00:7a"; ip = "192.168.50.7";};})]))
      && !(has "locally administered" (errsOf (add [(vm "vm-w" "lucas" {interfaces.lan = iface {mac = "a8:00:00:00:00:7a"; ip = "192.168.50.7";};})]))))]
    ["static in pool without lease warns" (has "is inside the DHCP pool" (warnsOf (add [(host "p" {interfaces.lan = iface {ip = "192.168.50.89"; static = true;};})])))]
    ["static outside pool is quiet" (!(has "inside the DHCP pool" (warnsOf (add [(host "p" {interfaces.lan = iface {ip = "192.168.50.237"; static = true;};})]))))]
    ["static in pool WITH a lease is quiet" (!(has "inside the DHCP pool" (warnsOf (add [(host "p" {interfaces.lan = iface {mac = "aa:00:00:00:00:7b"; ip = "192.168.50.89"; static = true;};})]))))]
    ["dhcp without mac warns" (has "uses DHCP but has no MAC" (warnsOf (add [(host "p" {interfaces.lan = iface {ip = "192.168.50.88";};})])))]
    ["host name goes to the primary only" (let m = (f.mk {hosts = add [(host "mattis" {interfaces = {
        wifi-lan = iface {mac = "60:6d:3c:ee:0a:94"; ip = "192.168.50.237"; static = true; primary = true; leaseName = "mattis-wifi";};
        lan = iface {mac = "10:65:30:e5:cd:78"; ip = "192.168.50.245"; leaseName = "mattis";};
        wifi = iface {mac = "9c:b6:d0:b8:88:af"; ip = "192.168.51.93"; zone = "wifi"; leaseName = "mattis";};
      };})]; inherit zones;}); in
      m.errors == [] && m.dns.mattis == "192.168.50.237" && m.dns."mattis.lan-hosts.example.com" == "192.168.50.237"
      && m.dns."mattis-wifi" == "192.168.50.237" && !(lib.any (n: lib.hasPrefix "mattis" n && m.dns.${n} == "192.168.50.245" && n == "mattis") (lib.attrNames m.dns)))]
    ["standby expose warns" (has "expose is ignored while the host is standby" (msgs r.warnings))]

    # ---- devices: DNS, clashes ----
    ["device dns is lower-case" (rd.dns."campnet-ap" == "192.168.50.200" && rd.dns."printer" == "192.168.51.50")]
    ["device fqdn uses the zone's hostDomain, none without one" (rd.dns."campnet-ap.lan-hosts.example.com" == "192.168.50.200" && !(rd.dns ? "printer.null"))]
    ["devices add no leases (they keep their files)" (!(lib.any (l: l.hostname == "Campnet-AP") (lib.concatLists (lib.attrValues rd.leases))))]
    ["devices do not disturb a clean fleet" (rd.errors == [])]
    ["device clashing with a host address" (has "address 192.168.50.16 is used by" (devErrs [{zone = "lan"; mac = "AA:11:00:00:00:09"; ip = "192.168.50.16"; hostname = "rogue";}]))]
    ["device clashing with a host MAC (any case)" (has "MAC 02:00:00:00:00:b0 is used by" (devErrs [{zone = "lan"; mac = "02:00:00:00:00:B0"; ip = "192.168.50.77"; hostname = "rogue";}]))]
    ["two devices clashing" (has "address 192.168.50.200 is used by" (devErrs [{zone = "lan"; mac = "AA:11:00:00:00:09"; ip = "192.168.50.200"; hostname = "twin";}]))]
    ["device name clashing with a host name" (has "resolves to different addresses" (devErrs [{zone = "lan"; mac = "AA:11:00:00:00:09"; ip = "192.168.50.77"; hostname = "VM-VAULT";}]))]
    ["device in an unknown zone" (has "unknown zone `nope`" (devErrs [{zone = "nope"; mac = "AA:11:00:00:00:09"; ip = "192.168.50.77"; hostname = "lost";}]))]
    ["device outside its zone is a warning" (has "outside zone `lan`" (devWarns [{zone = "lan"; mac = "AA:11:00:00:00:09"; ip = "192.168.99.5"; hostname = "far";}]))]

    # ---- DNS names are lower-case ----
    ["host dns is lower-case" (let m = f.mk {hosts = add [(host "UPPER" {interfaces.lan = iface {mac = "aa:00:00:00:00:7c"; ip = "192.168.50.99";}; dns.names = ["Svc.Example.COM"];})]; inherit zones;};
      in m.dns ? "upper" && m.dns ? "svc.example.com" && !(m.dns ? "UPPER") && !(m.dns ? "Svc.Example.COM"))]

    # ---- committed files ----
    ["leases file: sorted, quoted, one per line" (lib.hasInfix "  \"lan\" = [\n    {mac = \"aa:00:00:00:00:01\"; ip = \"192.168.50.1\"; hostname = \"blue-ridge\";}\n    {mac = \"02:00:00:00:00:10\"; ip = \"192.168.50.3\"; hostname = \"vault\";}\n" files.leases)]
    ["leases file has no devices" (!(lib.hasInfix "Campnet" files.leases))]
    ["dns file: sorted, lower-case" (lib.hasInfix "  \"campnet-ap\" = \"192.168.50.200\";\n" files.dns && lib.hasInfix "  \"vault\" = \"192.168.50.3\";\n" files.dns)]
    ["forwards are ordered by port, then protocol (tcp before udp)" (lib.hasInfix "protocol = \"tcp\"; description = \"Calls\";}\n  {port = 8443; destination = \"192.168.50.16\"; protocol = \"udp\";" files.forwards)]
    ["forwards file: destinationPort only when set" (lib.hasInfix "{port = 8443; destination = \"192.168.50.16\"; protocol = \"tcp\";" files.forwards
      && lib.hasInfix "protocol = \"udp\";" files.forwards && !(lib.hasInfix "destinationPort" files.forwards))]
    ["forwards destinationPort is rendered" (lib.hasInfix "destinationPort = 80;" (f.render (f.mk {hosts = add [(vm "vm-w" "lucas" {interfaces.lan = iface {mac = "02:00:00:00:00:7d"; ip = "192.168.50.98";}; expose = [(exposeE {port = 8080; destPort = 80;})];})]; inherit zones;})).forwards)]
    ["rendering is deterministic" (files == f.render (f.mk {inherit hosts zones; deviceLeases = devices;}))]
    ["retired is exempt from clashes" (!(has "192.168.50.20" (msgs r.errors)))]
    ["unmanaged hosts are ignored entirely" (!(has "some-unmanaged" (msgs (r.errors ++ r.warnings))))]
  ];

  failed = builtins.filter (x: !(builtins.elemAt x 1)) checks;
in
  if failed == []
  then "ok"
  else throw "fleet tests failed: ${builtins.concatStringsSep ", " (map builtins.head failed)}"
