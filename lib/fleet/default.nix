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
      inherit (h) kind lifecycle retired storage boot dns expose vault topology placement;
      interfaces = h.network.interfaces;
      vaultAgent = lib.attrByPath ["fmf" "services" "vault-agent" "enable"] false config;
      vaultServer = lib.attrByPath ["fmf" "services" "vault" "enable"] false config;
    };

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
        forIface = i: let
          zdom = domainOf i.zone;
          short = optionals h.dns.addAliases ([i.leaseName] ++ optional i.isPrimary h.name);
        in
          optionals (i.ip != null) (concatMap (n: [(nameValuePair n i.ip)] ++ optional (zdom != null) (nameValuePair "${n}.${zdom}" i.ip)) short);
        extra = optionals (primIp != null) (map (n: nameValuePair n primIp) h.dns.names);
      in
        concatMap forIface ifs ++ extra
    ) (attrValues live);
    dns = listToAttrs dnsEntries;

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
    guests = filter (h: h.kind == "microvm" && h.placement.runsOn != null) (attrValues live);
    guestsOf = hv: filter (h: h.placement.runsOn == hv) guests;
    # storage names in share order: by `order`, then name
    storageNames = h: sort (a: b: let oa = h.storage.${a}.order or 100; ob = h.storage.${b}.order or 100; in if oa != ob then oa < ob else a < b) (attrNames h.storage);
    hostPathOf = h: n: let s = h.storage.${n}; in if s.hostPath != null then s.hostPath else "/persist/vm-data/${h.name}/${n}";
    vaultDirOf = h: "/persist/system/var/lib/vault/${h.name}";

    directoriesOf = h:
      [
        {path = "/persist/vm-data/${h.name}"; mode = "0755";}
        {path = "/persist/vm-data/${h.name}/ssh"; mode = "0700";}
      ]
      ++ optional h.vaultAgent {path = vaultDirOf h; mode = "0700";}
      ++ map (n: {path = hostPathOf h n; mode = h.storage.${n}.mode;}) (attrNames h.storage);

    sharesOf = h:
      [
        {tag = "ro-store"; source = "/nix/store"; mountPoint = "/nix/.ro-store"; proto = "virtiofs";}
      ]
      ++ optional h.vaultAgent {tag = "vault-agent"; source = vaultDirOf h; mountPoint = "/var/lib/vault/${h.name}"; proto = "virtiofs";}
      ++ [
        {tag = "ssh-host-keys"; source = "/persist/vm-data/${h.name}/ssh"; mountPoint = "/persist/ssh"; proto = "virtiofs";}
        {tag = "root-password"; source = "/persist/system/secrets"; mountPoint = "/run/secrets"; proto = "virtiofs";}
      ]
      ++ map (n: let s = h.storage.${n}; in
        {tag = if s.tag != null then s.tag else n; source = hostPathOf h n; mountPoint = s.mountPoint; proto = "virtiofs";}
        // lib.optionalAttrs s.readOnly {readOnly = true;})
      (storageNames h);

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
      tmpfiles = map (d: "d ${d.path} ${d.mode} root root -") uniqDirs;
      shares = listToAttrs (map (h: nameValuePair h.name (sharesOf h)) gs);
      units = listToAttrs (concatMap unitsOf gs);
    })) (unique (map (h: h.placement.runsOn) guests)));

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
        ++ optional (i.mac == null && i.ip != null) (warn i.host "interface ${i.n}: has an address but no MAC, so no lease can be generated")
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
        optional (h.kind == "microvm" && hv == null) (err h.name "a MicroVM needs placement.runsOn")
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
      claims = concatMap (h: map (n: {host = h.name; path = hostPathOf h n; shared = h.storage.${n}.shared;}) (attrNames h.storage)) guests;
    in
      concatMap (g: let
          clash = length g > 1 && !(all (c: c.shared) g);
        in
          optional clash (err (head g).host "storage path ${(head g).path} is claimed by ${concatStringsSep ", " (map (c: c.host) g)} and not marked shared"))
      (attrValues (groupBy (c: c.path) claims));

    roleChecks = let
      claims = concatMap (h: map (r: {host = h.name; role = r;}) (rolesOf h)) (attrValues live);
    in
      concatMap (g: optional (length g > 1) (err (head g).host "Vault role `${(head g).role}` is claimed by ${concatStringsSep ", " (map (c: c.host) g)}"))
      (attrValues (groupBy (c: c.role) claims));

    dnsChecks = let
      byName = groupBy (e: e.name) dnsEntries;
    in
      concatMap (g: optional (length (unique (map (e: e.value) g)) > 1)
        (err "dns" "name `${(head g).name}` resolves to different addresses: ${concatStringsSep ", " (unique (map (e: e.value) g))}"))
      (attrValues byName);

    exposeChecks = concatMap (h: optional (h.expose != [] && h.lifecycle != "active") (warn h.name "expose is ignored while the host is ${h.lifecycle}")) (attrValues managed);

    all-problems =
      ifaceChecks
      ++ dupes "address" (i: i.ip) withIp
      ++ dupes "MAC" (i: toLower i.mac) (filter (i: i.mac != null) liveIfaces)
      ++ primaryChecks ++ placementChecks ++ bootChecks ++ cycleChecks ++ retiredRefs
      ++ storageChecks ++ roleChecks ++ dnsChecks ++ exposeChecks;
  in {
    hosts = {
      active = attrNames active;
      standby = attrNames standby;
      retired = attrNames retired;
      unmanaged = attrNames (filterAttrs (_: h: !h.managed) hosts);
    };
    inherit leases dns forwards vault hypervisors topology;
    errors = filter (p: p.level == "error") all-problems;
    warnings = filter (p: p.level == "warn") all-problems;
  };
in {
  fleet = {inherit extract mk parseIp parseCidr inSubnet;};
}
