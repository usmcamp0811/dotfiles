# lib.fmf.fleet: derive leases, DNS, port forwards, Vault roles, MicroVM hosting and boot order from
# the `fmf.host` records of a set of hosts. Pure Nix; nothing here touches a machine.
#
#   fleet.extract "<name>" config        one evaluated host -> plain data (or { managed = false; })
#   fleet.mk { hosts = { <name> = <extract result>; }; zones = <fmf.network.zones>; }
#
# `mk` returns { leases, dns, forwards, vault, hypervisors, topology, hosts, errors, warnings }.
# Specification: docs/HOST-MODEL.md.
{lib, ...}: let
  inherit
    (lib)
    all
    any
    attrNames
    attrValues
    concatLists
    concatMap
    concatStringsSep
    elem
    filter
    filterAttrs
    genericClosure
    groupBy
    hasPrefix
    head
    imap0
    length
    listToAttrs
    mapAttrs
    mapAttrsToList
    nameValuePair
    optional
    optionals
    removePrefix
    sort
    splitString
    toLower
    unique
    ;

  # ---- IPv4 ------------------------------------------------------------------------------------

  pow2 = n: lib.foldl' (a: _: a * 2) 1 (lib.range 1 n);

  parseIp = s: let
    parts = splitString "." s;
    nums = map (p: builtins.tryEval (lib.toInt p)) parts;
  in
    if length parts != 4 || !(all (n: n.success && n.value >= 0 && n.value <= 255) nums)
    then null
    else lib.foldl' (acc: n: acc * 256 + n.value) 0 nums;

  # null if `cidr` is not a.b.c.d/n
  parseCidr = cidr: let
    p = splitString "/" cidr;
    prefix = builtins.tryEval (lib.toInt (builtins.elemAt p 1));
    base = parseIp (head p);
  in
    if length p != 2 || base == null || !prefix.success || prefix.value < 0 || prefix.value > 32
    then null
    else {
      inherit base;
      prefix = prefix.value;
    };

  # inside a zone's DHCP pool (false when the zone has none)
  inPool = ip: z: let
    r = z.dhcpRange or null;
    i = parseIp ip;
  in
    r != null && i != null && parseIp r.start != null && parseIp r.end != null && i >= parseIp r.start && i <= parseIp r.end;

  inSubnet = ip: cidr: let
    i = parseIp ip;
    c = parseCidr cidr;
    d = pow2 (32 - c.prefix);
  in
    i != null && c != null && (i / d) == (c.base / d);

  # ---- MAC -------------------------------------------------------------------------------------

  hexDigit = c: (listToAttrs (imap0 (i: ch: nameValuePair ch i) (lib.stringToCharacters "0123456789abcdef"))).${toLower c};
  # a locally administered MAC has bit 1 of its first octet set (02, 06, 0a, 0e, 12, ...)
  locallyAdministered = mac: let
    n = hexDigit (builtins.substring 1 1 mac);
  in
    builtins.bitAnd n 2 != 0;

  # ---- extraction ------------------------------------------------------------------------------

  extract = name: config: let
    h = lib.attrByPath ["fmf" "host"] null config;
  in
    if h == null || h.kind == null
    then {
      inherit name;
      managed = false;
    }
    else {
      inherit name;
      managed = true;
      inherit (h) kind lifecycle retired storage boot dns expose vault topology placement derive nixStore standardShares;
      interfaces = h.network.interfaces;
      vaultAgent = lib.attrByPath ["fmf" "services" "vault-agent" "enable"] false config;
      vaultServer = lib.attrByPath ["fmf" "services" "vault" "enable"] false config;
      hypervisorNetworks = (h.hypervisor or {}).networks or {};
      # What the machine itself is configured with, so records can be checked against it.
      # A MicroVM's own interface definitions (empty on a physical host).
      # macvtap.link is an option without a default: reading it on a tap throws (an undefined option is not a
      # missing attribute, so `or` cannot catch it), hence only macvtap interfaces are asked for it.
      vmInterfaces = map (i: {
        type = i.type or null;
        id = i.id or null;
        mac = i.mac or null;
        macvtap =
          if (i.type or null) == "macvtap"
          then {link = i.macvtap.link or null; mode = i.macvtap.mode or null;}
          else {link = null; mode = null;};
      }) (lib.attrByPath ["microvm" "interfaces"] [] config);
      # systemd-networkd .network files: which interfaces they match, the bridge they enslave them to, addresses.
      networkd = lib.mapAttrsToList (name: n: let
        nc = n.networkConfig or {};
        asList = x: if x == null then [] else if builtins.isList x then x else [x];
      in {
        inherit name;
        match = lib.concatMap (lib.splitString " ") (map toString (asList ((n.matchConfig or {}).Name or null)));
        bridge = nc.Bridge or null;
        addresses = map toString (asList (nc.Address or null) ++ (n.address or []));
      }) (lib.attrByPath ["systemd" "network" "networks"] {} config);
      # Addresses set through networking.interfaces (the scripted alternative to networkd).
      interfaceAddresses = lib.concatMap (i: map (a: "${a.address}/${toString a.prefixLength}") ((i.ipv4 or {}).addresses or []))
        (lib.attrValues (lib.attrByPath ["networking" "interfaces"] {} config));
    };

  # ---- MicroVM guests: shares, store overlay and host directories --------------------------------
  #
  # Pure functions of one extracted record, so the hypervisor's view (`mk`) and the guest's own module
  # compute exactly the same thing. Share order is fixed: ro-store, rw-store, vault-agent,
  # ssh-host-keys, root-password, then the VM's `storage` entries by `order` and name.

  storageNames = h: sort (a: b: let oa = h.storage.${a}.order or 100; ob = h.storage.${b}.order or 100; in if oa != ob then oa < ob else a < b) (attrNames h.storage);
  hostPathOf = h: n: let s = h.storage.${n}; in if s.hostPath != null then s.hostPath else "/persist/vm-data/${h.name}/${n}";
  vaultDirOf = h: "/persist/system/var/lib/vault/${h.name}";
  hasVaultShare = h: if h.standardShares.vaultAgent != null then h.standardShares.vaultAgent else h.vaultAgent;
  hasRwStore = h: h.nixStore == "persistent";

  # what microvm.writableStoreOverlay should be (null = unset)
  overlayOf = h:
    if h.nixStore == "none"
    then null
    else "/nix/.rw-store";

  sharesOf = h:
    [
      {tag = "ro-store"; source = "/nix/store"; mountPoint = "/nix/.ro-store"; proto = "virtiofs";}
    ]
    ++ optional (hasRwStore h) {tag = "rw-store"; source = "/persist/vm-stores/${h.name}/nix-store"; mountPoint = "/nix/.rw-store"; proto = "virtiofs";}
    ++ optional (hasVaultShare h) {tag = "vault-agent"; source = vaultDirOf h; mountPoint = "/var/lib/vault/${h.name}"; proto = "virtiofs";}
    ++ [
      {tag = "ssh-host-keys"; source = "/persist/vm-data/${h.name}/ssh"; mountPoint = "/persist/ssh"; proto = "virtiofs";}
    ]
    ++ optional h.standardShares.rootPassword {tag = "root-password"; source = "/persist/system/secrets"; mountPoint = "/run/secrets"; proto = "virtiofs";}
    ++ map (n: let s = h.storage.${n}; in
      {tag = if s.tag != null then s.tag else n; source = hostPathOf h n; mountPoint = s.mountPoint; proto = "virtiofs";}
      // lib.optionalAttrs s.readOnly {readOnly = true;})
    (storageNames h);

  # directories the hypervisor creates for one guest (nothing when they are managed elsewhere).
  # /persist/system/secrets is shared by every guest and holds the host's own credentials: it is never
  # generated here.
  directoriesOf = h: let
    d = path: mode: {inherit path mode; owner = "root"; group = "root";};
  in
    optionals (h.placement.hostDirectories == "managed") (
      optionals (hasRwStore h) [(d "/persist/vm-stores/${h.name}" "0755") (d "/persist/vm-stores/${h.name}/nix-store" "0755")]
      ++ [(d "/persist/vm-data/${h.name}" "0755") (d "/persist/vm-data/${h.name}/ssh" "0700")]
      ++ optional (hasVaultShare h) (d (vaultDirOf h) "0700")
      ++ map (n: let s = h.storage.${n}; in {path = hostPathOf h n; inherit (s) mode owner group;}) (filter (n: h.storage.${n}.createDirectory or true) (attrNames h.storage))
    );

  # ---- helpers over extracted hosts ------------------------------------------------------------

  sortByIp = sort (a: b: (parseIp a.ip) < (parseIp b.ip));

  primaryOf = h: let
    names = attrNames h.interfaces;
    marked = filter (n: h.interfaces.${n}.primary == true) names;
  in
    if length marked == 1
    then head marked
    else if length marked == 0 && length names == 1
    then head names
    else null;

  leaseNameOf = h: ifname: let
    i = h.interfaces.${ifname};
    base =
      if h.kind == "microvm"
      then removePrefix "vm-" h.name
      else h.name;
  in
    if i.leaseName != null
    then i.leaseName
    else if primaryOf h == ifname
    then base
    else "${base}-${ifname}";

  ifaceList = h:
    map (n: let i = h.interfaces.${n}; in i // {inherit n; host = h.name; leaseName = leaseNameOf h n; isPrimary = primaryOf h == n;}) (attrNames h.interfaces);

  roleOf = h: if h.vault.role != null then h.vault.role else h.name;

  mk = {
    hosts,
    zones ? {},
    # Leases of machines that are not hosts (iot, wifi, appliances): { zone, mac, ip, hostname }.
    # They keep their own files; here they only take part in DNS and in the clash checks.
    deviceLeases ? [],
  }: let
    managed = filterAttrs (_: h: h.managed) hosts;
    ofLife = l: filterAttrs (_: h: h.lifecycle == l) managed;
    active = ofLife "active";
    standby = ofLife "standby";
    retired = ofLife "retired";
    live = active // standby; # provisioned: gets a lease, a role, DNS and placement
    liveIfaces = concatMap ifaceList (attrValues live);
    withIp = filter (i: i.ip != null) liveIfaces;
    zoneKnown = z: zones ? ${z};

    # ---- leases: { <zone> = [ { mac, ip, hostname } ] }, sorted by address ----
    leases =
      mapAttrs (_: is: map (i: {inherit (i) ip; mac = toLower i.mac; hostname = i.leaseName;}) (sortByIp is))
      (groupBy (i: i.zone) (filter (i: i.mac != null) withIp));

    # ---- DNS: { <name> = <ip> } ----
    dnsEntries = concatMap (
      h: let
        ifs = ifaceList h;
        prim = filter (i: i.isPrimary) ifs;
        primIp = if prim == [] then null else (head prim).ip;
        domainOf = z: zones.${z}.hostDomain or null;
        primDom = if prim == [] then null else domainOf (head prim).zone;
        # The bare host name belongs to the primary address. A non-primary interface whose lease is
        # also named like the host (a host on a second VLAN, or a stale extra NIC) only gets an FQDN,
        # and only in a different domain than the primary's, so `mattis` cannot resolve two ways.
        forIface = i: let
          zdom = domainOf i.zone;
          # DNS names are case-insensitive: everything is generated lower-case
          names = map toLower (optionals h.dns.addAliases ([i.leaseName] ++ optional i.isPrimary h.name));
          shortOk = n: i.isPrimary || n != toLower h.name;
          fqdnOk = n: i.isPrimary || n != toLower h.name || zdom != primDom;
        in
          optionals (i.ip != null) (concatMap (n:
            optional (shortOk n) (nameValuePair n i.ip)
            ++ optional (zdom != null && fqdnOk n) (nameValuePair "${n}.${zdom}" i.ip))
          (unique names));
        extra = optionals (primIp != null) (map (n: nameValuePair (toLower n) primIp) h.dns.names);
      in
        concatMap forIface ifs ++ extra
    ) (attrValues live);
    # devices (no host record): their own name, plus the FQDN in their zone's host domain
    deviceDns = concatMap (d: let
      n = toLower d.hostname;
      dom = zones.${d.zone}.hostDomain or null;
    in
      [(nameValuePair n d.ip)] ++ optional (dom != null) (nameValuePair "${n}.${dom}" d.ip))
    deviceLeases;
    allDns = dnsEntries ++ deviceDns;
    dns = listToAttrs allDns;

    # ---- port forwards (active hosts only) ----
    forwards = concatMap (
      h: let
        p = primaryOf h;
        ip = if p == null then null else h.interfaces.${p}.ip;
      in
        optionals (ip != null) (map (e: {
            inherit (e) port description;
            protocol = e.proto;
            destination = ip;
            destPort = e.destPort;
          })
          h.expose)
    ) (attrValues active);

    # ---- Vault: roles, expected addresses, roles of retired hosts to remove ----
    ipsOf = h: sort builtins.lessThan (unique (map (i: i.ip) (filter (i: i.ip != null) (ifaceList h))));
    rolesOf = h: [(roleOf h)] ++ h.vault.aliases;
    vault = {
      roles = listToAttrs (concatMap (h:
        [(nameValuePair (roleOf h) {host = h.name; extraPolicies = h.vault.extraPolicies; aliasOf = null;})]
        ++ map (a: nameValuePair a {host = h.name; extraPolicies = h.vault.extraPolicies; aliasOf = roleOf h;}) h.vault.aliases)
      (attrValues live));
      expectedIps = filterAttrs (_: v: v != []) (listToAttrs (concatMap (h: map (r: nameValuePair r (ipsOf h)) (rolesOf h)) (attrValues live)));
      retiredRoles = sort builtins.lessThan (concatMap rolesOf (attrValues retired));
    };

    # ---- hypervisors ----
    placed = filter (h: h.kind == "microvm" && h.placement.runsOn != null) (attrValues live);
    # only VMs that opted in (`derive`) have their hypervisor side generated
    guests = filter (h: h.derive) placed;
    guestsOf = hv: filter (h: h.placement.runsOn == hv) guests;

    unitsOf = h: let
      deps = map (d: "microvm@${d}.service") h.boot.after ++ h.boot.hostUnits;
    in
      optionals (deps != []) [(nameValuePair "microvm@${h.name}" {after = deps; wants = deps;})];

    hypervisors = listToAttrs (map (hv: nameValuePair hv (let
      gs = guestsOf hv;
      dirs = concatMap directoriesOf gs;
      uniqDirs = lib.attrValues (listToAttrs (map (d: nameValuePair d.path d) dirs));
    in {
      vms = listToAttrs (map (h: nameValuePair h.name ({
          autostart = h.lifecycle == "active" && h.placement.autostart;
        }
        // lib.optionalAttrs (h.placement.restartIfChanged != null) {restartIfChanged = h.placement.restartIfChanged;})) gs);
      directories = uniqDirs;
      tmpfiles = map (d: "d ${d.path} ${d.mode} ${d.owner} ${d.group} -") uniqDirs;
      shares = listToAttrs (map (h: nameValuePair h.name (sharesOf h)) gs);
      overlays = listToAttrs (map (h: nameValuePair h.name (overlayOf h)) gs);
      units = listToAttrs (concatMap unitsOf gs);
    })) (unique (map (h: h.placement.runsOn) guests)));

    # ---- network attachment (phase 4): which bridge or NIC each guest interface reaches the network through ----
    # One row per interface of a placed MicroVM. `target` is the hypervisor's attachment for that zone (null when the
    # hypervisor has not described its networks yet, or not this zone).
    tapIdOf = h: n: let
      i = h.interfaces.${n};
    in
      if (i.id or null) != null
      then i.id
      else if n == primaryOf h
      then h.name
      else "${h.name}-${n}";
    mapOf = hv: (managed.${hv} or {}).hypervisorNetworks or {};
    attachRows = concatMap (h:
      map (n: let
        i = h.interfaces.${n};
      in {
        vm = h.name;
        hv = h.placement.runsOn;
        ifname = n;
        id = tapIdOf h n;
        inherit (i) zone mac;
        attach = i.attach or "tap";
        target = (mapOf h.placement.runsOn).${i.zone} or null;
      }) (attrNames h.interfaces))
    placed;
    # networkd's Name= is a list of shell globs; the first .network file (in lexical order) that matches wins.
    globMatch = glob: s: let
      escaped = lib.escapeRegex glob;
      re = builtins.replaceStrings ["\\*" "\\?"] [".*" "."] escaped;
    in
      builtins.match re s != null;
    landingOf = hv: id: let
      files = sort (a: b: a.name < b.name) ((managed.${hv} or {}).networkd or []);
      hit = lib.findFirst (f: any (g: globMatch g id) f.match) null files;
    in
      if hit == null
      then null
      else {inherit (hit) name bridge;};
    attachments = mapAttrs (_: rows: map (r: r // {landing = landingOf r.hv r.id;}) rows) (groupBy (r: r.hv) attachRows);

    # ---- topology hints (live hosts) ----
    topology = mapAttrs (_: h: filterAttrs (_: v: v != null && v != []) {inherit (h.topology) role location rack tags;}) live;

    # ---- assertions ----
    err = host: message: {level = "error"; inherit host message;};
    warn = host: message: {level = "warn"; inherit host message;};

    ifaceChecks = concatMap (i: let
        z = zones.${i.zone} or null;
      in
        optional (zones != {} && !(zoneKnown i.zone)) (err i.host "interface ${i.n}: unknown zone `${i.zone}`")
        ++ optional (i.ip != null && parseIp i.ip == null) (err i.host "interface ${i.n}: `${i.ip}` is not an IPv4 address")
        ++ optional (i.ip != null && z != null && parseIp i.ip != null && parseCidr z.subnet != null && !(inSubnet i.ip z.subnet))
        (err i.host "interface ${i.n}: ${i.ip} is outside zone `${i.zone}` (${z.subnet})")
        ++ optional (i.mac == null && i.ip != null && !i.static) (warn i.host "interface ${i.n}: uses DHCP but has no MAC, so no lease can be generated for ${i.ip}")
        ++ optional (i.mac == null && i.ip != null && i.static && z != null && inPool i.ip z)
        (warn i.host "interface ${i.n}: static ${i.ip} is inside the DHCP pool of `${i.zone}` and no lease reserves it (give the interface its MAC)")
        ++ optional (i.mac != null && live.${i.host}.kind == "microvm" && !(locallyAdministered i.mac))
        (warn i.host "interface ${i.n}: ${i.mac} is not a locally administered MAC (its second hex digit should be 2, 6, a or e)"))
    liveIfaces;

    dupes = what: key: items:
      concatMap (g:
        optional (length g > 1)
        (err (head g).host "${what} ${key (head g)} is used by ${concatStringsSep ", " (unique (map (x: x.host) g))}"))
      (attrValues (groupBy key items));

    primaryChecks = concatMap (h: let
        ifs = attrNames h.interfaces;
        marked = filter (n: h.interfaces.${n}.primary == true) ifs;
      in
        optional (length marked > 1) (err h.name "more than one interface is marked primary: ${concatStringsSep ", " marked}")
        ++ optional (length ifs > 1 && length marked == 0) (err h.name "has ${toString (length ifs)} interfaces and none is marked primary")
        ++ optional (ifs == []) (warn h.name "has no network interface")) (attrValues live);

    refName = h: n: "${h.name}: ${n}";
    placementChecks = concatMap (h: let
        hv = h.placement.runsOn;
        target = managed.${hv} or null;
      in
        optional (h.kind == "microvm" && hv == null && h.lifecycle == "active") (err h.name "an active MicroVM needs placement.runsOn (a standby one may be unplaced)")
        ++ optional (h.kind == "physical" && hv != null) (warn h.name "placement.runsOn is ignored on a physical host")
        ++ optionals (hv != null && h.kind == "microvm") (
          optional (target == null) (err h.name "runsOn `${hv}` is not a host managed by the model")
          ++ optional (target != null && target.kind != "physical") (err h.name "runsOn `${hv}` is not a physical host")
          ++ optional (target != null && target.lifecycle == "retired") (err h.name "runsOn `${hv}` is retired")
        )) (attrValues live);

    bootChecks = concatMap (h: let
        deps = h.boot.after;
        depHost = d: managed.${d} or null;
        bad = d: let t = depHost d; in
          if d == h.name then err h.name "boot.after lists itself"
          else if t == null then err h.name "boot.after `${d}` is not a managed host"
          else if t.lifecycle == "retired" then err h.name "boot.after `${d}` is retired"
          else if t.kind != "microvm" then err h.name "boot.after `${d}` is not a MicroVM (use boot.hostUnits for units on the hypervisor)"
          else if t.placement.runsOn != h.placement.runsOn then err h.name "boot.after `${d}` runs on `${toString t.placement.runsOn}`, not on `${toString h.placement.runsOn}`: ordering across machines is not possible"
          else null;
      in
        filter (x: x != null) (map bad deps)) (attrValues live);

    # a cycle: a VM reachable from its own dependencies
    cycleChecks = let
      depsOf = n: filter (d: (live.${d} or null) != null && live.${d}.kind == "microvm" && d != n) (live.${n}.boot.after or []);
    in
      concatMap (n: let
          reach = map (x: x.key) (genericClosure {
            startSet = map (d: {key = d;}) (depsOf n);
            operator = x: map (d: {key = d;}) (depsOf x.key);
          });
        in
          optional (elem n reach) (err n "boot.after forms a cycle through ${n}"))
      (attrNames (filterAttrs (_: h: h.kind == "microvm") live));

    retiredRefs = concatMap (h: let
        refs = h.boot.after ++ optional (h.placement.runsOn != null) h.placement.runsOn;
      in
        map (r: err h.name "refers to retired host `${r}`") (filter (r: (retired.${r} or null) != null) refs)) (attrValues live);

    storageChecks = let
      claims = concatMap (h: map (n: {host = h.name; path = hostPathOf h n; shared = h.storage.${n}.shared;}) (attrNames h.storage)) placed;
    in
      concatMap (g: let
          clash = length g > 1 && !(all (c: c.shared) g);
        in
          optional clash (err (head g).host "storage path ${(head g).path} is claimed by ${concatStringsSep ", " (map (c: c.host) g)} and not marked shared"))
      (attrValues (groupBy (c: c.path) claims));

    # network attachment: errors for what cannot work, warnings where the record and the evaluated machine disagree
    attachChecks =
      concatMap (r: let
          described = mapOf r.hv != {};
          t = r.target;
        in
          optional (builtins.stringLength r.id > 15) (err r.vm "interface ${r.ifname}: hypervisor name `${r.id}` is longer than 15 characters (set network.interfaces.${r.ifname}.id)")
          ++ optional (described && t == null) (err r.vm "interface ${r.ifname}: ${r.hv} has no attachment for zone `${r.zone}` (fmf.host.hypervisor.networks.${r.zone})")
          ++ optional (t != null && r.attach == "tap" && t.bridge == null) (err r.vm "interface ${r.ifname} is a tap, but ${r.hv} attaches zone `${r.zone}` with macvtap")
          ++ optional (t != null && r.attach == "macvtap" && t.macvtap == null) (err r.vm "interface ${r.ifname} is a macvtap, but ${r.hv} attaches zone `${r.zone}` to a bridge"))
      attachRows
      ++ concatMap (rows: dupes "hypervisor interface name" (x: x.id) (map (x: x // {host = x.vm;}) rows)) (attrValues (groupBy (r: r.hv) attachRows))
      ++ concatMap (h:
        concatMap (z: let
            a = h.hypervisorNetworks.${z};
          in
            optional ((a.bridge == null) == (a.macvtap == null)) (err h.name "hypervisor.networks.${z}: set exactly one of bridge and macvtap")
            ++ optional (zones != {} && !(zoneKnown z)) (err h.name "hypervisor.networks.${z}: unknown zone"))
        (attrNames (h.hypervisorNetworks or {})))
      (attrValues live);

    attachDrift = concatMap (r: let
        actual = (managed.${r.vm} or {}).vmInterfaces or [];
        mine = lib.findFirst (i: i.mac != null && r.mac != null && toLower i.mac == toLower r.mac) null actual;
        t = r.target;
        l = landingOf r.hv r.id;
        networkd = (managed.${r.hv} or {}).networkd or [];
      in
        optionals (actual != []) (
          optional (mine == null) (warn r.vm "interface ${r.ifname} (${toString r.mac}) is not among the VM's microvm.interfaces")
          ++ optionals (mine != null) (
            optional (mine.id != r.id) (warn r.vm "interface ${r.ifname} is named `${toString mine.id}` on the hypervisor; the record implies `${r.id}`")
            ++ optional (mine.type != r.attach) (warn r.vm "interface ${r.ifname} is a ${toString mine.type}; the record says ${r.attach}")
            ++ optional (r.attach == "macvtap" && t != null && t.macvtap != null && (mine.macvtap.link != t.macvtap.link || mine.macvtap.mode != t.macvtap.mode))
            (warn r.vm "interface ${r.ifname}: macvtap on ${toString mine.macvtap.link} (${toString mine.macvtap.mode}); ${r.hv} attaches zone `${r.zone}` on ${t.macvtap.link} (${t.macvtap.mode})")
          ))
        ++ optionals (r.attach == "tap" && t != null && t.bridge != null && networkd != []) (
          optional (l == null) (warn r.vm "interface ${r.ifname}: no .network file on ${r.hv} matches `${r.id}`, so it joins no bridge (zone `${r.zone}` attaches to ${t.bridge})")
          ++ optional (l != null && l.bridge != t.bridge)
          (warn r.vm "interface ${r.ifname}: `${r.id}` joins ${toString l.bridge} on ${r.hv} (first match: ${l.name}), but zone `${r.zone}` attaches to ${t.bridge}")
        ))
    attachRows
    # a guest interface that the record does not have
    ++ concatMap (h:
      map (i: warn h.name "the VM has an interface (${toString i.id}, ${toString i.mac}) that its record does not")
      (filter (i: !(any (n: h.interfaces.${n}.mac != null && i.mac != null && toLower h.interfaces.${n}.mac == toLower i.mac) (attrNames h.interfaces))) (h.vmInterfaces or [])))
    placed;

    # a static address in the record that the machine does not configure (only checked where it configures any)
    addressDrift = concatMap (h: let
        configured = map (a: head (splitString "/" a))
          (concatMap (f: f.addresses) (h.networkd or []) ++ (h.interfaceAddresses or []));
      in
        optionals (configured != [])
        (concatMap (n: let
            i = h.interfaces.${n};
          in
            optional (i.static && i.ip != null && !(elem i.ip configured))
            (warn h.name "interface ${n}: ${i.ip} is static in the record but the machine configures ${concatStringsSep ", " (unique configured)}"))
        (attrNames h.interfaces)))
    (attrValues live);

    roleChecks = let
      claims = concatMap (h: map (r: {host = h.name; role = r;}) (rolesOf h)) (attrValues live);
    in
      concatMap (g: optional (length g > 1) (err (head g).host "Vault role `${(head g).role}` is claimed by ${concatStringsSep ", " (map (c: c.host) g)}"))
      (attrValues (groupBy (c: c.role) claims));

    dnsChecks = let
      byName = groupBy (e: e.name) allDns;
    in
      concatMap (g: optional (length (unique (map (e: e.value) g)) > 1)
        (err "dns" "name `${(head g).name}` resolves to different addresses: ${concatStringsSep ", " (unique (map (e: e.value) g))}"))
      (attrValues byName);

    exposeChecks = concatMap (h: optional (h.expose != [] && h.lifecycle != "active") (warn h.name "expose is ignored while the host is ${h.lifecycle}")) (attrValues managed);

    # devices take part in the address and MAC clash checks, so a device lease can never collide with a host
    deviceItems = map (d: d // {host = "device ${d.hostname}";}) deviceLeases;
    deviceChecks = concatMap (d: let
        z = zones.${d.zone} or null;
      in
        optional (zones != {} && z == null) (err "device ${d.hostname}" "unknown zone `${d.zone}`")
        ++ optional (parseIp d.ip == null) (err "device ${d.hostname}" "`${d.ip}` is not an IPv4 address")
        ++ optional (z != null && parseIp d.ip != null && parseCidr z.subnet != null && !(inSubnet d.ip z.subnet))
        (warn "device ${d.hostname}" "${d.ip} is outside zone `${d.zone}` (${z.subnet})"))
    deviceLeases;

    all-problems =
      ifaceChecks
      ++ deviceChecks
      ++ dupes "address" (i: i.ip) (withIp ++ deviceItems)
      ++ dupes "MAC" (i: toLower i.mac) (filter (i: i.mac != null) liveIfaces ++ deviceItems)
      ++ primaryChecks ++ placementChecks ++ bootChecks ++ cycleChecks ++ retiredRefs
      ++ storageChecks ++ roleChecks ++ dnsChecks ++ exposeChecks
      ++ attachChecks ++ attachDrift ++ addressDrift;
  in {
    hosts = {
      active = attrNames active;
      standby = attrNames standby;
      retired = attrNames retired;
      unmanaged = attrNames (filterAttrs (_: h: !h.managed) hosts);
    };
    inherit leases dns forwards vault hypervisors topology attachments;
    errors = filter (p: p.level == "error") all-problems;
    warnings = filter (p: p.level == "warn") all-problems;
  };

  # ---- committed files ----------------------------------------------------------------------------
  #
  # `mk` result -> the text of the files a downstream repository commits and its consumers import:
  #   leases   { <zone> = [ { mac; ip; hostname; } ]; }   host leases only (device leases keep their files)
  #   dns      { "<name>" = "<ip>"; }                      hosts and devices, lower-case
  #   forwards [ { port; destination; protocol; description; destinationPort?; } ]  forwards to hosts
  # Deterministic (sorted), so a check can compare them byte for byte with what is committed.
  render = r: let
    q = lib.strings.escapeNixString;
    header = ''
      # GENERATED by `fleet` (fmf package; see docs/HOST-MODEL.md). Do not edit: change a host's
      # fmf.host record (or a device lease) and regenerate.
    '';
    leaseLine = l: "    {mac = ${q l.mac}; ip = ${q l.ip}; hostname = ${q l.hostname};}\n";
    leases =
      header
      + "{\n"
      + concatStringsSep "" (mapAttrsToList (z: ls: "  ${q z} = [\n${concatStringsSep "" (map leaseLine ls)}  ];\n") r.leases)
      + "}\n";
    dns =
      header
      + "{\n"
      + concatStringsSep "" (mapAttrsToList (n: ip: "  ${q n} = ${q ip};\n") r.dns)
      + "}\n";
    ordered = sort (a: b:
      if a.port != b.port
      then a.port < b.port
      else if a.protocol != b.protocol
      then a.protocol < b.protocol
      else a.destination < b.destination)
    r.forwards;
    forwardLine = f:
      "  {port = ${toString f.port}; destination = ${q f.destination}; protocol = ${q f.protocol}; description = ${q f.description};"
      + lib.optionalString (f.destPort != null) " destinationPort = ${toString f.destPort};"
      + "}\n";
    forwards = header + "[\n" + concatStringsSep "" (map forwardLine ordered) + "]\n";

    # microvms: { "<hypervisor>" = { vms; tmpfiles; units; }; } for VMs that set fmf.host.derive. The
    # consumer adds `flake` to each VM. Everything is sorted, so it compares byte for byte.
    list = xs: "[" + concatStringsSep " " (map q xs) + "]";
    vmLine = n: v:
      "      ${q n} = {autostart = ${lib.boolToString v.autostart};"
      + lib.optionalString (v ? restartIfChanged) " restartIfChanged = ${lib.boolToString v.restartIfChanged};"
      + "};\n";
    unitLine = n: u: "      ${q n} = {after = ${list u.after}; wants = ${list u.wants};};\n";
    hvBlock = hv: x:
      "  ${q hv} = {\n    vms = {\n"
      + concatStringsSep "" (mapAttrsToList vmLine x.vms)
      + "    };\n    tmpfiles = [\n"
      + concatStringsSep "" (map (t: "      ${q t}\n") x.tmpfiles)
      + "    ];\n    units = {\n"
      + concatStringsSep "" (mapAttrsToList unitLine x.units)
      + "    };\n  };\n";
    microvms = header + "{\n" + concatStringsSep "" (mapAttrsToList hvBlock r.hypervisors) + "}\n";
  in {inherit leases dns forwards microvms;};
in {
  fleet = {inherit extract mk render parseIp parseCidr inSubnet inPool sharesOf overlayOf directoriesOf;};
}
