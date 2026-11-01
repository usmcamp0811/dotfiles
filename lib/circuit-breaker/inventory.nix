# Circuit Breaker inventory exporter.
#
# Pure Nix: turns a set of *evaluated* NixOS systems (`nixosConfigurations`)
# into a deterministic, versioned, Circuit-Breaker-independent inventory
# document (schema version 1). Nothing here greps source files and nothing
# serialises a whole configuration tree: every datum is read through an
# explicit, defensive accessor, so a removed/renamed/throwing option degrades
# to "absent" (plus a diagnostic) instead of breaking the export.
#
# Secrets: the exporter only reads an allow-list of option paths (names,
# addresses, ports, images, MACs, WireGuard *public* keys). It never reads
# `environment`, `environmentFiles`, `*File`, `password*`, `*Key` (private),
# `credentials`, `login`, or `extraConfig`-style free text. A schema-level
# guard in the reconciler additionally rejects secret-looking keys.
{lib}: let
  net = import ./net.nix {inherit lib;};
  catalogFile = import ./catalog.nix;

  schemaVersion = 1;
  generatorVersion = "1";

  # ---------------------------------------------------------------- helpers

  # Deep-force `v`; any evaluation error yields `default`. Only ever applied
  # to small scalar-ish values (never to packages or whole config trees).
  safe = default: v: let
    r = builtins.tryEval (builtins.deepSeq v v);
  in
    if r.success
    then r.value
    else default;

  # Defensive accessor. Containers (attrsets, lists of attrsets) stay lazy so a
  # throwing option nested inside them cannot poison siblings; scalars and
  # lists of scalars are fully forced so they can be serialised safely.
  at = cfg: path: default: let
    r = builtins.tryEval (lib.attrByPath path default cfg);
    forced = builtins.tryEval (builtins.deepSeq r.value r.value);
    elems = builtins.tryEval (builtins.all (e: !(builtins.isAttrs e)) r.value);
  in
    if !r.success
    then default
    else if builtins.isAttrs r.value
    then r.value
    else if builtins.isList r.value
    then
      (
        if !elems.success
        then default
        else if !elems.value
        then r.value
        else if forced.success
        then forced.value
        else default
      )
    else if forced.success
    then forced.value
    else default;

  asList = v:
    if v == null
    then []
    else if builtins.isList v
    then v
    else [v];

  nonNull = lib.filterAttrs (_: v: v != null);

  sortStrings = xs: lib.sort (a: b: a < b) xs;
  sortBy = f: xs: lib.sort (a: b: f a < f b) xs;
  uniq = xs: lib.unique xs;

  lower = lib.toLower;

  # Glob match with `*` wildcards only (what networkd matchConfig / our own
  # exclude lists need).
  globToRegex = g: lib.concatStringsSep ".*" (map lib.escapeRegex (lib.splitString "*" g));
  globMatch = pattern: s: builtins.match (globToRegex pattern) s != null;
  anyGlob = patterns: s: builtins.any (p: globMatch p s) patterns;

  normMac = m:
    if builtins.isString m
    then lower m
    else null;

  # Attribute names usable inside resource ids.
  slug = s: lib.replaceStrings [" " "/"] ["-" "-"] (toString s);

  # ---------------------------------------------------------------- options

  defaultOptions = {
    # nixosConfigurations attribute names to leave out entirely.
    excludeSystems = [];
    # Extra/overriding catalog entries (same shape as catalog.nix).
    extraCatalog = {};
    # fmf.services names to ignore in addition to catalog.ignore.
    ignoreServices = [];
    # Report DHCP reservations that match no NixOS system as devices.
    includeUnmatchedReservations = false;
    monitoring = {
      enable = true;
      intervalSecs = 60;
      icmp = true;
      ssh = true;
      tcpKinds = ["reverse-proxy" "database" "cache" "dns" "auth" "secrets" "scm" "orchestrator"];
      http = true;
      httpVerifyTls = true;
      preferPublishedUrl = true;
      dnsQueryName = null;
      # Resource ids / globs to never monitor.
      exclude = [];
    };
  };

  mergeOptions = user:
    defaultOptions
    // user
    // {
      monitoring = defaultOptions.monitoring // (user.monitoring or {});
    };

  # ------------------------------------------------------- per-system facts

  hintsPath = ["fmf" "services" "circuit-breaker" "hints"];

  extractSystem = opts: catalog: name: sys: let
    cfg = sys.config;
    get = path: default: at cfg path default;
    getIn = attrs: path: default: at attrs path default;

    platform =
      safe null
      (lib.attrByPath ["pkgs" "stdenv" "hostPlatform" "system"]
        (get ["nixpkgs" "hostPlatform" "system"] null)
        sys);

    hostName = get ["networking" "hostName"] name;
    domain = get ["networking" "domain"] null;

    hypervisor = get ["microvm" "hypervisor"] null;
    isGuest = hypervisor != null;

    # ---- microvm guest facts (only when this system *is* a MicroVM)
    guestInterfaces = lib.optionals isGuest (map
      (i: {
        type = getIn i ["type"] null;
        id = getIn i ["id"] null;
        mac = normMac (getIn i ["mac"] null);
      })
      (get ["microvm" "interfaces"] []));

    guestShares = lib.optionals isGuest (map
      (s: {
        proto = getIn s ["proto"] null;
        source = getIn s ["source"] null;
        mountPoint = getIn s ["mountPoint"] null;
      })
      (get ["microvm" "shares"] []));

    # ---- MicroVMs this system hosts
    hostedVms = let
      vms = safe {} (builtins.mapAttrs
        (_: v: {
          autostart = getIn v ["autostart"] null;
          restartIfChanged = getIn v ["restartIfChanged"] null;
        })
        (get ["microvm" "vms"] {}));
    in
      vms;

    # ---- networking
    networkdNetworks = let
      raw = get ["systemd" "network" "networks"] {};
    in
      safe {} (lib.mapAttrs
        (key: n: let
          nc = getIn n ["networkConfig"] {};
          names = lib.concatMap (s: lib.splitString " " s) (asList (getIn n ["matchConfig" "Name"] null));
          addrs = map toString (asList (getIn n ["address"] []) ++ asList (getIn nc ["Address"] []));
          gws = map toString (asList (getIn n ["gateway"] []) ++ asList (getIn nc ["Gateway"] []));
        in {
          inherit key;
          names = lib.filter (s: s != "") names;
          mac = normMac (getIn n ["matchConfig" "MACAddress"] null);
          addresses = addrs;
          gateways = gws;
          bridge = getIn nc ["Bridge"] null;
          bond = getIn nc ["Bond"] null;
          vlans = map toString (asList (getIn n ["vlan"] []));
          dhcp = let
            d = getIn nc ["DHCP"] null;
          in
            if d == null
            then null
            else toString d;
          routes =
            map
            (r: {
              destination = getIn r ["routeConfig" "Destination"] null;
              gateway = getIn r ["routeConfig" "Gateway"] null;
            })
            (getIn n ["routes"] []);
        })
        raw);

    networkdNetdevs = safe {} (lib.mapAttrs
      (key: d: {
        inherit key;
        kind = getIn d ["netdevConfig" "Kind"] null;
        name = getIn d ["netdevConfig" "Name"] null;
        mac = normMac (getIn d ["netdevConfig" "MACAddress"] null);
        vlanId = getIn d ["vlanConfig" "Id"] null;
        peers =
          map
          (p: {
            publicKey = getIn p ["wireguardPeerConfig" "PublicKey"] null;
            allowedIps = map toString (asList (getIn p ["wireguardPeerConfig" "AllowedIPs"] []));
            endpoint = getIn p ["wireguardPeerConfig" "Endpoint"] null;
          })
          (getIn d ["wireguardPeers"] []);
      })
      (get ["systemd" "network" "netdevs"] {}));

    # systemd.network.links: matchConfig.MACAddress -> linkConfig.Name (guest NIC names)
    networkdLinks = safe [] (lib.mapAttrsToList
      (_: l: {
        mac = normMac (getIn l ["matchConfig" "MACAddress"] null);
        name = getIn l ["linkConfig" "Name"] null;
      })
      (get ["systemd" "network" "links"] {}));

    legacyInterfaces = safe {} (lib.mapAttrs
      (n: i: {
        v4 = map (a: "${toString (getIn a ["address"] "")}/${toString (getIn a ["prefixLength"] 0)}") (getIn i ["ipv4" "addresses"] []);
        v6 = map (a: "${toString (getIn a ["address"] "")}/${toString (getIn a ["prefixLength"] 0)}") (getIn i ["ipv6" "addresses"] []);
        dhcp = getIn i ["useDHCP"] null;
        mac = normMac (getIn i ["macAddress"] null);
      })
      (get ["networking" "interfaces"] {}));

    legacyBridges = safe {} (lib.mapAttrs (_: b: map toString (getIn b ["interfaces"] [])) (get ["networking" "bridges"] {}));
    legacyVlans = safe {} (lib.mapAttrs
      (_: v: {
        id = getIn v ["id"] null;
        interface = getIn v ["interface"] null;
      })
      (get ["networking" "vlans"] {}));
    legacyBonds = safe {} (lib.mapAttrs (_: b: map toString (getIn b ["interfaces"] [])) (get ["networking" "bonds"] {}));

    wireguard = safe {} (lib.mapAttrs
      (_: w: {
        ips = map toString (asList (getIn w ["ips"] []));
        listenPort = getIn w ["listenPort"] null;
        peers =
          map
          (p: {
            publicKey = getIn p ["publicKey"] null;
            allowedIps = map toString (asList (getIn p ["allowedIPs"] []));
            endpoint = getIn p ["endpoint"] null;
          })
          (getIn w ["peers"] []);
      })
      (get ["networking" "wireguard" "interfaces"] {}));

    # ---- interfaces (merged view across networkd + legacy + wireguard)
    mkAddr = s: net.parseCidr s;
    dropBad = lib.filter (a: a != null);

    ifaceFromNetwork = n:
      map
      (nm: {
        name = nm;
        mac = n.mac;
        addresses = dropBad (map mkAddr n.addresses);
        gateways = n.gateways;
        master =
          if n.bridge != null
          then n.bridge
          else n.bond;
        vlanChildren = n.vlans;
        dhcp = n.dhcp;
        routes = n.routes;
        source = "systemd.network";
      })
      (lib.filter (nm: !(lib.hasInfix "*" nm)) n.names);

    ifaceFromNetdev = d:
      lib.optional (d.name != null) {
        name = d.name;
        mac = d.mac;
        kind = d.kind;
        vlanId = d.vlanId;
        peers = d.peers;
        source = "systemd.network.netdev";
      };

    ifaceFromLegacy = n: i: {
      name = n;
      mac = i.mac;
      addresses = dropBad (map mkAddr (i.v4 ++ i.v6));
      dhcp =
        if i.dhcp == true
        then "yes"
        else null;
      source = "networking.interfaces";
    };

    ifaceFromWg = n: w: {
      name = n;
      kind = "wireguard";
      addresses = dropBad (map mkAddr w.ips);
      listenPort = w.listenPort;
      peers = w.peers;
      source = "networking.wireguard";
    };

    rawIfaces =
      lib.concatMap ifaceFromNetwork (lib.attrValues networkdNetworks)
      ++ lib.concatMap ifaceFromNetdev (lib.attrValues networkdNetdevs)
      ++ lib.mapAttrsToList ifaceFromLegacy legacyInterfaces
      ++ lib.mapAttrsToList ifaceFromWg wireguard
      ++ lib.concatLists (lib.mapAttrsToList (b: members:
        map (m: {
          name = m;
          master = b;
          source = "networking.bridges";
        })
        members)
      legacyBridges)
      ++ lib.concatLists (lib.mapAttrsToList (b: members:
        map (m: {
          name = m;
          master = b;
          source = "networking.bonds";
        })
        members)
      legacyBonds)
      ++ lib.mapAttrsToList (n: v: {
        name = n;
        kind = "vlan";
        vlanId = v.id;
        parent = v.interface;
        source = "networking.vlans";
      })
      legacyVlans
      ++ map (b: {
        name = b;
        kind = "bridge";
        source = "networking.bridges";
      }) (builtins.attrNames legacyBridges)
      ++ map (b: {
        name = b;
        kind = "bond";
        source = "networking.bonds";
      }) (builtins.attrNames legacyBonds);

    firstNonNull = xs: lib.findFirst (x: x != null) null xs;
    mergeIface = name: parts: let
      f = k: firstNonNull (map (p: p.${k} or null) parts);
      allOf = k: lib.concatMap (p: p.${k} or []) parts;
    in {
      inherit name;
      kind = f "kind";
      mac = f "mac";
      vlanId = f "vlanId";
      master = f "master";
      parent = f "parent";
      dhcp = f "dhcp";
      listenPort = f "listenPort";
      addresses = lib.unique (allOf "addresses");
      gateways = lib.unique (allOf "gateways");
      vlanChildren = lib.unique (allOf "vlanChildren");
      routes = allOf "routes";
      peers = allOf "peers";
      sources = sortStrings (lib.unique (map (p: p.source) parts));
    };

    mergedIfaces = let
      grouped = lib.groupBy (p: p.name) rawIfaces;
    in
      lib.mapAttrs mergeIface grouped;

    # Interface kind: explicit netdev kind wins; otherwise infer.
    ifaceKind = i:
      if i.kind != null
      then i.kind
      else if i.vlanId != null
      then "vlan"
      else "ethernet";

    # VLAN parent from networkd `vlan = [ ... ]` lists on the parent network.
    vlanParents = lib.foldl' (acc: i: acc // lib.genAttrs i.vlanChildren (_: i.name)) {} (lib.attrValues mergedIfaces);

    finalIfaces = sortBy (i: i.name) (lib.mapAttrsToList
      (n: i:
        nonNull {
          name = n;
          kind = ifaceKind i;
          mac = i.mac;
          vlanId = i.vlanId;
          master = i.master;
          parent =
            if i.parent != null
            then i.parent
            else vlanParents.${n} or null;
          dhcp = i.dhcp;
          listenPort = i.listenPort;
          addresses = map (a: {inherit (a) family address prefixLength cidr;}) i.addresses;
          gateways = sortStrings i.gateways;
          peers =
            if i.peers == []
            then null
            else sortBy (p: toString (p.publicKey or "")) (map nonNull i.peers);
          sources = i.sources;
        })
      mergedIfaces);

    # First-match-wins attachment rules for taps created by a hypervisor.
    attachRules =
      map
      (n: {
        key = n.key;
        names = n.names;
        bridge = n.bridge;
      })
      (lib.sort (a: b: a.key < b.key) (lib.attrValues networkdNetworks));

    defaultGateway = firstNonNull (
      [(get ["networking" "defaultGateway" "address"] null)]
      ++ lib.concatMap (i: i.gateways) finalIfaces
    );

    nameservers = get ["networking" "nameservers"] [];

    firewall = let
      enabled = get ["networking" "firewall" "enable"] null;
    in {
      inherit enabled;
      tcp = sortStrings' (get ["networking" "firewall" "allowedTCPPorts"] []);
      udp = sortStrings' (get ["networking" "firewall" "allowedUDPPorts"] []);
      interfaces = safe {} (lib.mapAttrs
        (_: v: {
          tcp = getIn v ["allowedTCPPorts"] [];
          udp = getIn v ["allowedUDPPorts"] [];
        })
        (get ["networking" "firewall" "interfaces"] {}));
    };
    sortStrings' = xs: lib.sort (a: b: a < b) (lib.unique xs);

    # ---- DHCP reservations declared by the router module (global for the site)
    zones = safe {} (lib.mapAttrs
      (zn: z: {
        vlanId = getIn z ["vlanId"] null;
        subnet = getIn z ["subnet"] null;
        gateway = getIn z ["gateway"] null;
        description = getIn z ["description"] null;
        isolation = getIn z ["isolation"] null;
        leases =
          map
          (l: {
            mac = normMac (getIn l ["mac"] null);
            ip = getIn l ["ip"] null;
            hostname = getIn l ["hostname"] null;
          })
          (getIn z ["dhcp" "staticLeases"] []);
      })
      (get ["fmf" "router" "zones" "zones"] {}));

    # ---- services
    tcpInts = map (p:
      if builtins.isInt p
      then p
      else lib.toInt (toString p)) (get ["networking" "firewall" "allowedTCPPorts"] []);
    udpInts = map (p:
      if builtins.isInt p
      then p
      else lib.toInt (toString p)) (get ["networking" "firewall" "allowedUDPPorts"] []);
    ifaceTcpInts = lib.concatMap (v: map (p: lib.toInt (toString p)) v.tcp) (lib.attrValues firewall.interfaces);

    exposure = proto: port: let
      open =
        if proto == "udp"
        then udpInts
        else tcpInts;
    in
      if firewall.enabled == false
      then "firewall-disabled"
      else if builtins.elem port open
      then "open"
      else if proto == "tcp" && builtins.elem port ifaceTcpInts
      then "interface"
      else "closed";

    ignoreSet = catalog.ignore ++ opts.ignoreServices;
    catalogEntries = catalog.entries;

    intOrNull = v:
      if builtins.isInt v
      then v
      else null;

    fmfServices = let
      all = get ["fmf" "services"] {};
      names = builtins.attrNames all;
      enabledNames = lib.filter (n: (safe false (getIn all [n "enable"] false)) == true) names;
    in
      lib.filter (s: s != null) (map
        (n: let
          entry = catalogEntries.${n} or null;
          port = intOrNull (safe null (getIn all [n "port"] null));
          ports =
            if port != null
            then [port]
            else if entry != null
            then entry.ports or []
            else [];
        in
          if builtins.elem n ignoreSet || (ports == [] && entry == null)
          then null
          else if ports == [] && entry != null && (entry.ports or []) == []
          then {
            key = n;
            source = "fmf.services.${n}";
            kind = entry.kind;
            ports = [];
          }
          else {
            key = n;
            source = "fmf.services.${n}";
            kind =
              if entry != null
              then entry.kind
              else "application";
            ports = ports;
          })
        enabledNames);

    upstreamServices = lib.filter (s: s != null) (lib.mapAttrsToList
      (n: entry:
        if !(entry.upstream or false) || builtins.elem n ignoreSet
        then null
        else if (safe false (get ["services" n "enable"] false)) != true
        then null
        else let
          explicit =
            if entry ? portPath
            then intOrNull (safe null (get (["services" n] ++ entry.portPath) null))
            else null;
          ports =
            if explicit != null
            then [explicit]
            else entry.ports or [];
        in {
          key = n;
          source = "services.${n}";
          kind = entry.kind;
          inherit ports;
        })
      catalogEntries);

    sshServices = let
      enabled = (safe false (get ["services" "openssh" "enable"] false)) == true;
      ports = map (p:
        if builtins.isInt p
        then p
        else lib.toInt (toString p)) (get ["services" "openssh" "ports"] [22]);
    in
      lib.optional enabled {
        key = "ssh";
        source = "services.openssh";
        kind = "remote-access";
        inherit ports;
      };

    # Dedupe fmf-vs-upstream by key; the fmf definition (explicit port) wins.
    services = let
      all = fmfServices ++ upstreamServices ++ sshServices;
      byKey = lib.listToAttrs (map (s: lib.nameValuePair s.key s) (lib.reverseList all));
    in
      sortBy (s: s.key) (lib.attrValues byKey);

    # ---- containers
    parsePort = spec: let
      s = toString spec;
      parts = lib.splitString ":" s;
      hostPart = lib.elemAt parts (lib.length parts - 2);
      m = builtins.match "([0-9]+)(/(tcp|udp))?" (lib.last parts);
    in
      if lib.length parts >= 2 && builtins.match "[0-9]+" hostPart != null
      then {
        port = lib.toInt hostPart;
        protocol =
          if m != null && builtins.elemAt m 2 != null
          then builtins.elemAt m 2
          else "tcp";
      }
      else null;

    ociContainers = safe {} (lib.mapAttrs
      (_: c: {
        image = getIn c ["image"] null;
        ports = lib.filter (p: p != null) (map parsePort (getIn c ["ports"] []));
        autoStart = getIn c ["autoStart"] null;
      })
      (get ["virtualisation" "oci-containers" "containers"] {}));

    nixosContainers = safe {} (lib.mapAttrs
      (_: c: {
        localAddress = getIn c ["localAddress"] null;
        hostAddress = getIn c ["hostAddress"] null;
        autoStart = getIn c ["autoStart"] null;
        forwards =
          map
          (f: {
            port = getIn f ["hostPort"] null;
            protocol = getIn f ["protocol"] "tcp";
          })
          (getIn c ["forwardPorts"] []);
      })
      (get ["containers"] {}));

    # ---- storage
    remoteFsTypes = ["nfs" "nfs4" "cifs" "glusterfs" "9p" "ceph"];
    localFsTypes = ["ext4" "ext3" "xfs" "btrfs" "zfs" "bcachefs" "f2fs"];
    fileSystems = let
      all = safe {} (lib.mapAttrs
        (mp: f: {
          device = getIn f ["device"] null;
          fsType = getIn f ["fsType"] null;
          options = map toString (getIn f ["options"] []);
        })
        (get ["fileSystems"] {}));
    in
      lib.filter (f: f != null) (lib.mapAttrsToList
        (mp: f:
          if builtins.elem "bind" f.options || f.fsType == "none"
          then null
          else if builtins.elem f.fsType remoteFsTypes
          then {
            kind = "remote-mount";
            mountPoint = mp;
            fsType = f.fsType;
            device = f.device;
          }
          else if builtins.elem f.fsType localFsTypes
          then {
            kind = "filesystem";
            mountPoint = mp;
            fsType = f.fsType;
            device = f.device;
          }
          else null)
        all);

    disks = safe [] (lib.mapAttrsToList
      (dn: d: {
        kind = "disk";
        name = dn;
        device = getIn d ["device"] null;
      })
      (get ["disko" "devices" "disk"] {}));

    zfsPools = map (p: {
      kind = "zfs-pool";
      name = toString p;
    }) (safe [] (get ["boot" "zfs" "extraPools"] []));

    luks = (get ["boot" "initrd" "luks" "devices"] {}) != {};

    # ---- reverse-proxy routing (Traefik dynamic configuration)
    traefikDynamic = let
      fromFmf = get ["fmf" "services" "traefik" "dynamicConfigOptions"] null;
      fromUpstream = get ["services" "traefik" "dynamicConfigOptions"] null;
    in
      if fromFmf != null && fromFmf != {}
      then fromFmf
      else if fromUpstream != null
      then fromUpstream
      else {};

    traefikRoutes = let
      routers = getIn traefikDynamic ["http" "routers"] {};
      svcs = getIn traefikDynamic ["http" "services"] {};
      hostsOf = rule: let
        ms = builtins.split "Host\\(`([^`]+)`\\)" (toString rule);
      in
        lib.concatMap (x:
          if builtins.isList x
          then [(builtins.head x)]
          else [])
        ms;
    in
      sortBy (r: r.router) (lib.mapAttrsToList
        (rn: r: let
          sn = getIn r ["service"] null;
          servers = map (s: getIn s ["url"] null) (asList (getIn svcs [sn "loadBalancer" "servers"] []));
        in {
          router = rn;
          hostnames = sortStrings (lib.unique (hostsOf (getIn r ["rule"] "")));
          service = sn;
          backends = lib.filter (u: u != null) servers;
        })
        routers);

    # ---- cross-service references (for service-to-service relationships)
    vaultAddress = get ["fmf" "services" "vault-agent" "settings" "vault" "address"] null;
    vaultAgentEnabled = (get ["fmf" "services" "vault-agent" "enable"] false) == true;

    # ---- hints
    hints = let
      h = get hintsPath {};
    in {
      ignore = getIn h ["ignore"] false;
      displayName = getIn h ["displayName"] null;
      role = getIn h ["role"] null;
      location = getIn h ["location"] null;
      rack = getIn h ["rack"] null;
      tags = map toString (getIn h ["tags"] []);
      monitoring = getIn h ["monitoring" "enable"] null;
      connections =
        map
        (c: {
          to = getIn c ["to"] null;
          type = getIn c ["type"] "ethernet";
          bandwidthMbps = getIn c ["bandwidthMbps"] null;
          label = getIn c ["label"] null;
        })
        (getIn h ["connections"] []);
      services = safe {} (lib.mapAttrs
        (_: s: {
          ignore = getIn s ["ignore"] false;
          displayName = getIn s ["displayName"] null;
          kind = getIn s ["kind"] null;
          url = getIn s ["url"] null;
        })
        (getIn h ["services"] {}));
      extraServices =
        map
        (s: {
          name = getIn s ["name"] null;
          kind = getIn s ["kind"] "application";
          port = getIn s ["port"] null;
          protocol = getIn s ["protocol"] "tcp";
          url = getIn s ["url"] null;
        })
        (getIn h ["extraServices"] []);
      networks = safe {} (lib.mapAttrs
        (_: n: {
          cidr = getIn n ["cidr"] null;
          vlanId = getIn n ["vlanId"] null;
          gateway = getIn n ["gateway"] null;
          description = getIn n ["description"] null;
        })
        (getIn h ["networks"] {}));
      devices = safe {} (lib.mapAttrs
        (_: d: {
          displayName = getIn d ["displayName"] null;
          role = getIn d ["role"] null;
          vendor = getIn d ["vendor"] null;
          model = getIn d ["model"] null;
          address = getIn d ["address"] null;
          mac = normMac (getIn d ["mac"] null);
          location = getIn d ["location"] null;
          rack = getIn d ["rack"] null;
          tags = map toString (getIn d ["tags"] []);
          monitoring = getIn d ["monitoring" "enable"] null;
          connections =
            map
            (c: {
              to = getIn c ["to"] null;
              type = getIn c ["type"] "ethernet";
              bandwidthMbps = getIn c ["bandwidthMbps"] null;
              label = getIn c ["label"] null;
            })
            (getIn d ["connections"] []);
        })
        (getIn h ["devices"] {}));
    };

    # ---- misc host facts
    cpuVendor =
      if (get ["hardware" "cpu" "intel" "updateMicrocode"] false) == true
      then "intel"
      else if (get ["hardware" "cpu" "amd" "updateMicrocode"] false) == true
      then "amd"
      else null;

    isRouter = (get ["fmf" "router" "enable"] false) == true;
    isHypervisorHost = hostedVms != {};
    hasK3s = (get ["services" "k3s" "enable"] false) == true || (get ["fmf" "services" "k3s" "enable"] false) == true;
  in {
    inherit
      name
      platform
      hostName
      domain
      isGuest
      hypervisor
      guestInterfaces
      guestShares
      hostedVms
      networkdLinks
      attachRules
      defaultGateway
      nameservers
      firewall
      zones
      services
      ociContainers
      nixosContainers
      hints
      cpuVendor
      isRouter
      isHypervisorHost
      hasK3s
      traefikRoutes
      vaultAddress
      vaultAgentEnabled
      exposure
      luks
      ;
    interfaces = finalIfaces;
    storage = fileSystems ++ disks ++ zfsPools;
    vcpu =
      if isGuest
      then get ["microvm" "vcpu"] null
      else null;
    memoryMb =
      if isGuest
      then get ["microvm" "mem"] null
      else null;
    osRelease = get ["system" "nixos" "release"] null;
    configurationRevision = get ["system" "configurationRevision"] null;
  };

  # ------------------------------------------------------------ assembling

  mkRes = {
    id,
    type,
    name,
    parent ? null,
    attributes ? {},
    tags ? [],
    origin,
  }: {
    inherit id type name origin;
    parent = parent;
    attributes = nonNull attributes;
    tags = sortStrings (uniq tags);
    state = "declared";
  };

  mkRel = {
    type,
    from,
    to,
    attributes ? {},
    origin,
  }: {
    id = "rel/${type}/${from}/${to}${
      if attributes ? qualifier
      then "/${attributes.qualifier}"
      else ""
    }";
    inherit type from to origin;
    attributes = nonNull attributes;
  };

  mkInventory = {
    nixosConfigurations,
    flake ? {},
    options ? {},
  }: let
    opts = mergeOptions options;
    catalog = {
      entries = catalogFile.catalog // opts.extraCatalog;
      ignore = catalogFile.ignore;
    };

    systemNames = lib.filter (n: !(builtins.elem n opts.excludeSystems)) (builtins.attrNames nixosConfigurations);
    allFacts = lib.genAttrs systemNames (n: extractSystem opts catalog n nixosConfigurations.${n});
    factsList = map (n: allFacts.${n}) systemNames;
    # Systems that opted out through hints.ignore never appear.
    visible = lib.filterAttrs (_: f: !f.hints.ignore) allFacts;
    visibleNames = builtins.attrNames visible;

    # ---- MicroVM placement: guest attr name -> [ host attr names ]
    placements = let
      pairs = lib.concatMap (hn: map (vn: {inherit hn vn;}) (builtins.attrNames visible.${hn}.hostedVms)) visibleNames;
      grouped = lib.groupBy (p: p.vn) pairs;
    in
      lib.mapAttrs (_: ps: sortStrings (uniq (map (p: p.hn) ps))) grouped;

    isVmSystem = n: visible.${n}.isGuest || placements ? ${n};
    resIdOf = n:
      if isVmSystem n
      then "vm/${n}"
      else "host/${n}";

    # ---- DHCP reservations: mac -> reservation
    # A MAC may legitimately be reserved in several zones (the same locally
    # administered MAC reused on different VLANs), so this is mac -> [reservation].
    allReservations = let
      all = lib.concatMap (n:
        lib.concatLists (lib.mapAttrsToList
          (zn: z:
            map (l: l // {zone = zn;}) (lib.filter (l: l.mac != null && l.ip != null) z.leases))
          visible.${n}.zones))
      visibleNames;
      # Every system sees the same site-wide router config; dedupe identical entries.
      byKey = lib.listToAttrs (map (l: lib.nameValuePair "${l.mac}/${l.zone}/${l.ip}" l) all);
    in
      sortBy (l: "${l.mac}/${l.zone}/${l.ip}") (lib.attrValues byKey);
    reservations = lib.groupBy (l: l.mac) allReservations;

    # ---- networks (global): router zones, hint networks, then derived CIDRs
    zoneNetworks = lib.concatMap (n:
      lib.mapAttrsToList
      (zn: z: {
        id = "net/${slug zn}";
        name = zn;
        cidr = (net.parseCidr z.subnet).cidr or null;
        vlanId = z.vlanId;
        gateway = z.gateway;
        description = z.description;
        isolation = z.isolation;
        origin = {
          kind = "nixosConfiguration";
          ref = n;
          path = "fmf.router.zones.zones.${zn}";
        };
      })
      (lib.filterAttrs (_: z: z.subnet != null && net.parseCidr z.subnet != null) visible.${n}.zones))
    visibleNames;

    hintNetworks = lib.concatMap (n:
      lib.mapAttrsToList
      (nn: h: {
        id = "net/${slug nn}";
        name = nn;
        cidr = (net.parseCidr h.cidr).cidr or null;
        vlanId = h.vlanId;
        gateway = h.gateway;
        description = h.description;
        isolation = null;
        origin = {
          kind = "hint";
          ref = n;
          path = "fmf.services.circuit-breaker.hints.networks.${nn}";
        };
      })
      (lib.filterAttrs (_: h: h.cidr != null && net.parseCidr h.cidr != null) visible.${n}.hints.networks))
    visibleNames;

    declaredNetworks = let
      all = zoneNetworks ++ hintNetworks;
      byCidr = lib.foldl' (acc: nw:
        if acc ? ${nw.cidr}
        then acc
        else acc // {${nw.cidr} = nw;}) {}
      all;
    in
      lib.attrValues byCidr;

    # Every static address of every visible system, as (cidr) candidates.
    staticAddrsOf = f:
      lib.concatMap (i:
        lib.filter
        (a: !(net.isLoopback a.address) && !(net.isLinkLocal a.address) && a.family == "ipv4" && a.prefixLength < 32)
        i.addresses)
      f.interfaces;

    derivedCidrs = let
      all = lib.concatMap (n: map (a: a.cidr) (staticAddrsOf visible.${n})) visibleNames;
      declaredCidrs = map (nw: nw.cidr) declaredNetworks;
    in
      lib.filter (c: !(builtins.elem c declaredCidrs)) (sortStrings (uniq all));

    derivedNetworks =
      map
      (c: {
        id = "net/${slug c}";
        name = c;
        cidr = c;
        vlanId = null;
        gateway = null;
        description = null;
        isolation = null;
        origin = {
          kind = "derived";
          ref = c;
          path = "interface-address";
        };
      })
      derivedCidrs;

    allNetworks = sortBy (n: n.id) (declaredNetworks ++ derivedNetworks);

    networkContaining = address:
      lib.findFirst (nw: net.inCidr nw.cidr address) null
      (sortBy (nw: (net.parseCidr nw.cidr).prefixLength * (-1)) allNetworks);

    # ---- per-system derived addressing
    # Addresses for one system: static ones declared on interfaces + a DHCP
    # reservation matched by the MAC of a declared NIC.
    systemMacs = f:
      lib.filter (m: m != null) (
        map (i: i.mac or null) f.interfaces
        ++ map (i: i.mac or null) f.guestInterfaces
      );

    # Pick the DHCP reservation for a system. When its MAC is reserved in
    # several zones, prefer the entry whose hostname names this system; if still
    # ambiguous, report none rather than guess.
    reservationFor = f: let
      cands = lib.concatMap (mac: reservations.${mac} or []) (systemMacs f);
      names = map lower [f.name f.hostName (lib.removePrefix "vm-" f.hostName) (lib.removePrefix "vm-" f.name)];
      named = lib.filter (r: r.hostname != null && builtins.elem (lower r.hostname) names) cands;
    in
      if cands == []
      then null
      else if lib.length cands == 1
      then builtins.head cands
      else if lib.length named == 1
      then builtins.head named
      else null;

    guestNicName = f: mac: let
      l = lib.findFirst (l: l.mac == mac && l.name != null) null f.networkdLinks;
    in
      if l == null
      then null
      else l.name;

    staticV4 = f:
      lib.concatMap (i:
        map (a: {
          inherit (a) address cidr prefixLength;
          interface = i.name;
        })
        (lib.filter (a: a.family == "ipv4" && !(net.isLoopback a.address) && !(net.isLinkLocal a.address)) i.addresses))
      f.interfaces;

    # Primary address preference: address on the interface that carries the
    # default gateway; otherwise the first static address; otherwise a DHCP
    # reservation; otherwise unknown.
    primaryOf = f: let
      statics = staticV4 f;
      gwIface = lib.findFirst (i: i.gateways or [] != []) null f.interfaces;
      onGw =
        if gwIface == null
        then []
        else lib.filter (a: a.interface == gwIface.name) statics;
      res = reservationFor f;
    in
      if onGw != []
      then {
        address = (builtins.head onGw).address;
        source = "static";
        interface = (builtins.head onGw).interface;
      }
      else if statics != []
      then {
        address = (builtins.head statics).address;
        source = "static";
        interface = (builtins.head statics).interface;
      }
      else if res != null
      then {
        address = res.ip;
        source = "dhcp-reservation";
        interface = null;
        zone = res.zone;
      }
      else null;

    primaries = lib.genAttrs visibleNames (n: primaryOf visible.${n});

    # ---- bridge attachment of hypervisor taps (first matching .network wins)
    tapAttachment = host: tapId: let
      matches = lib.filter (r: anyGlob r.names tapId) visible.${host}.attachRules;
      first =
        if matches == []
        then null
        else builtins.head matches;
      shadowed = lib.filter (r: r.bridge != null && first != null && r.key != first.key && r.bridge != first.bridge) matches;
    in {
      bridge =
        if first == null
        then null
        else first.bridge;
      rule =
        if first == null
        then null
        else first.key;
      shadowed =
        map (r: {
          rule = r.key;
          bridge = r.bridge;
        })
        shadowed;
    };

    # ---- storage mounts of guests (virtiofs shares from the host)
    guestStorage = f:
      lib.concatMap (s:
        lib.optional (s.source != null && s.source != "/nix/store" && s.proto == "virtiofs") {
          kind = "virtiofs-share";
          hostPath = s.source;
          mountPoint = s.mountPoint;
        })
      f.guestShares;

    # ================================================================ resources
    placedHostsOf = n: placements.${n} or [];
    primaryHostOf = n: let
      ps = placedHostsOf n;
    in
      if ps == []
      then null
      else builtins.head ps;

    roleTags = f:
      (lib.optional f.isRouter "role:router")
      ++ (lib.optional f.isHypervisorHost "role:hypervisor")
      ++ (lib.optional f.hasK3s "role:kubernetes")
      ++ (lib.optional (f.hints.role != null) "role:${f.hints.role}")
      ++ f.hints.tags;

    systemResource = n: let
      f = visible.${n};
      isVm = isVmSystem n;
      parentHost = primaryHostOf n;
      prim = primaries.${n};
      guestIfaces =
        map
        (gi:
          nonNull {
            type = gi.type;
            tapId = gi.id;
            mac = gi.mac;
            name = guestNicName f gi.mac;
            attachedTo =
              if parentHost != null && gi.id != null
              then (tapAttachment parentHost gi.id).bridge
              else null;
          })
        f.guestInterfaces;
    in
      mkRes {
        id = resIdOf n;
        type =
          if isVm
          then "vm"
          else "host";
        name =
          if f.hints.displayName != null
          then f.hints.displayName
          else f.hostName;
        parent =
          if isVm && parentHost != null
          then "host/${parentHost}"
          else null;
        tags = roleTags f;
        origin = {
          kind = "nixosConfiguration";
          ref = n;
        };
        attributes = {
          hostName = f.hostName;
          fqdn =
            if f.domain != null
            then "${f.hostName}.${f.domain}"
            else null;
          os = "nixos";
          osRelease = f.osRelease;
          platform = f.platform;
          architecture =
            if f.platform == null
            then null
            else builtins.head (lib.splitString "-" f.platform);
          configurationRevision = f.configurationRevision;
          primaryAddress =
            if prim == null
            then null
            else prim.address;
          addressSource =
            if prim == null
            then null
            else prim.source;
          defaultGateway = f.defaultGateway;
          nameservers = f.nameservers;
          interfaces = f.interfaces;
          guestInterfaces =
            if isVm && guestIfaces != []
            then guestIfaces
            else null;
          firewall = {
            enabled = f.firewall.enabled;
            openTcpPorts = f.firewall.tcp;
            openUdpPorts = f.firewall.udp;
          };
          storage = sortBy (s: "${s.kind}:${s.mountPoint or s.name or ""}") (f.storage ++ lib.optionals isVm (guestStorage f));
          encryptedStorage =
            if f.luks
            then true
            else null;
          cpuVendor = f.cpuVendor;
          vcpu = f.vcpu;
          memoryMb = f.memoryMb;
          hypervisor =
            if isVm
            then f.hypervisor
            else null;
          placement =
            if isVm
            then
              (
                if parentHost == null
                then "unplaced"
                else "placed"
              )
            else null;
          placementHosts =
            if isVm && lib.length (placedHostsOf n) > 1
            then placedHostsOf n
            else null;
          autostart =
            if isVm && parentHost != null
            then visible.${parentHost}.hostedVms.${n}.autostart or null
            else null;
          location = f.hints.location;
          rack = f.hints.rack;
          monitoringEnabled = f.hints.monitoring;
        };
      };

    deviceResources = lib.concatMap (n:
      lib.mapAttrsToList
      (dn: d:
        mkRes {
          id = "device/${slug dn}";
          type = "device";
          name =
            if d.displayName != null
            then d.displayName
            else dn;
          tags = d.tags ++ (lib.optional (d.role != null) "role:${d.role}");
          origin = {
            kind = "hint";
            ref = n;
            path = "fmf.services.circuit-breaker.hints.devices.${dn}";
          };
          attributes = {
            role = d.role;
            vendor = d.vendor;
            model = d.model;
            primaryAddress = d.address;
            addressSource =
              if d.address != null
              then "hint"
              else null;
            mac = d.mac;
            location = d.location;
            rack = d.rack;
            monitoringEnabled = d.monitoring;
          };
        })
      visible.${n}.hints.devices)
    visibleNames;

    networkResources =
      map
      (nw:
        mkRes {
          id = nw.id;
          type = "network";
          name = nw.name;
          origin = nw.origin;
          attributes = {
            cidr = nw.cidr;
            vlanId = nw.vlanId;
            gateway = nw.gateway;
            description = nw.description;
            isolation = nw.isolation;
          };
        })
      allNetworks;

    # ---- services & containers
    ownerId = n: resIdOf n;

    serviceResources = lib.concatMap (n: let
      f = visible.${n};
      owner = ownerId n;
      ownerPrimary = primaries.${n};
      viaHint = key: f.hints.services.${key} or null;
      published = key: pubIndex.${owner}.${key} or [];
    in
      (lib.concatMap
        (s: let
          h = viaHint s.key;
        in
          lib.optional (h == null || !h.ignore) (mkRes {
            id = "svc/${n}/${s.key}";
            type = "service";
            name =
              if h != null && h.displayName != null
              then h.displayName
              else s.key;
            parent = owner;
            origin = {
              kind = "nixosConfiguration";
              ref = n;
              path = s.source;
            };
            tags = [
              "kind:${
                if h != null && h.kind != null
                then h.kind
                else s.kind
              }"
            ];
            attributes = {
              kind =
                if h != null && h.kind != null
                then h.kind
                else s.kind;
              source = s.source;
              address =
                if ownerPrimary == null
                then null
                else ownerPrimary.address;
              ports =
                map
                (p: {
                  port = p;
                  protocol = "tcp";
                  exposure = f.exposure "tcp" p;
                })
                s.ports;
              publishedHostnames =
                if published s.key == []
                then null
                else published s.key;
              url =
                if h != null && h.url != null
                then h.url
                else null;
            };
          }))
        f.services)
      ++ (lib.concatMap
        (e:
          lib.optional (e.name != null) (mkRes {
            id = "svc/${n}/${slug e.name}";
            type = "service";
            name = e.name;
            parent = owner;
            origin = {
              kind = "hint";
              ref = n;
              path = "fmf.services.circuit-breaker.hints.extraServices";
            };
            tags = ["kind:${e.kind}"];
            attributes = {
              kind = e.kind;
              source = "hint";
              address =
                if ownerPrimary == null
                then null
                else ownerPrimary.address;
              ports = lib.optional (e.port != null) {
                port = e.port;
                protocol = e.protocol;
                exposure = "unknown";
              };
              url = e.url;
            };
          }))
        f.hints.extraServices))
    visibleNames;

    containerResources = lib.concatMap (n: let
      f = visible.${n};
      owner = ownerId n;
    in
      (lib.mapAttrsToList
        (cn: c:
          mkRes {
            id = "container/${n}/${slug cn}";
            type = "container";
            name = cn;
            parent = owner;
            origin = {
              kind = "nixosConfiguration";
              ref = n;
              path = "virtualisation.oci-containers.containers.${cn}";
            };
            tags = ["runtime:oci"];
            attributes = {
              runtime = "oci";
              image = c.image;
              autoStart = c.autoStart;
              ports = map (p: {inherit (p) port protocol;}) c.ports;
            };
          })
        f.ociContainers)
      ++ (lib.mapAttrsToList
        (cn: c:
          mkRes {
            id = "container/${n}/${slug cn}";
            type = "container";
            name = cn;
            parent = owner;
            origin = {
              kind = "nixosConfiguration";
              ref = n;
              path = "containers.${cn}";
            };
            tags = ["runtime:nixos-container"];
            attributes = {
              runtime = "nixos-container";
              autoStart = c.autoStart;
              address = c.localAddress;
              hostAddress = c.hostAddress;
              ports = lib.filter (p: p.port != null) c.forwards;
            };
          })
        f.nixosContainers))
    visibleNames;

    # ---- endpoint resolution (host/ip/name + port -> inventory resource)
    ownedAddresses = n: let
      f = visible.${n};
      statics = map (a: a.address) (staticV4 f);
      res = reservationFor f;
    in
      statics ++ lib.optional (res != null) res.ip;

    addrIndex =
      lib.foldl' (acc: n:
        lib.foldl' (a: ip: a // {${ip} = (a.${ip} or []) ++ [n];}) acc (ownedAddresses n))
      {}
      visibleNames;

    nameIndex = let
      entries = lib.concatMap (n: let
        f = visible.${n};
        res = reservationFor f;
        short = lib.removePrefix "vm-" n;
      in
        map (k: {
          key = lower k;
          value = n;
        }) (lib.filter (k: k != null) ([n f.hostName (lib.removePrefix "vm-" f.hostName)] ++ lib.optional (res != null) res.hostname)))
      visibleNames;
    in
      lib.foldl' (acc: e:
        if acc ? ${e.key}
        then acc
        else acc // {${e.key} = e.value;}) {}
      entries;

    parseEndpoint = url: let
      m = builtins.match "([a-zA-Z][a-zA-Z0-9+.-]*)://([^/:?#]+)(:([0-9]+))?([/?#].*)?" (toString url);
    in
      if m == null
      then null
      else {
        scheme = builtins.elemAt m 0;
        host = builtins.elemAt m 1;
        port =
          if builtins.elemAt m 3 != null
          then lib.toInt (builtins.elemAt m 3)
          else if builtins.elemAt m 0 == "https"
          then 443
          else if builtins.elemAt m 0 == "http"
          then 80
          else null;
      };

    systemOfHost = host: let
      h = lower host;
      stripped = builtins.head (lib.splitString "." h);
    in
      if net.isV4 host
      then let
        owners = addrIndex.${host} or [];
      in
        if owners == []
        then null
        else builtins.head owners
      else nameIndex.${h} or nameIndex.${stripped} or null;

    serviceOnPort = n: port: let
      f = visible.${n};
      owner = ownerId n;
      candidates = lib.filter (s: builtins.elem port s.ports) f.services;
    in
      if candidates != []
      then "svc/${n}/${(builtins.head candidates).key}"
      else null;

    # Resolve a backend (ip or inventory hostname + port) to { target, sys } or null.
    resolveBackend = host: port: let
      n = systemOfHost host;
    in
      if n == null
      then null
      else let
        svc =
          if port == null
          then null
          else serviceOnPort n port;
      in {
        sys = n;
        target =
          if svc != null
          then svc
          else ownerId n;
        isService = svc != null;
      };

    # published hostnames per owner/service-key, derived from reverse-proxy routes
    routeEdges = lib.concatMap (n: let
      f = visible.${n};
      proxySvc = lib.findFirst (s: s.key == "traefik") null f.services;
    in
      lib.optionals (proxySvc != null) (lib.concatMap
        (r:
          lib.concatMap (u: let
            ep = parseEndpoint u;
            # A loopback backend is a service on the proxy's own system.
            selfSvc =
              if ep == null || !(net.isLoopback ep.host || ep.host == "localhost")
              then null
              else serviceOnPort n ep.port;
            res =
              if ep == null
              then null
              else if net.isLoopback ep.host || ep.host == "localhost"
              then {
                sys = n;
                target =
                  if selfSvc != null
                  then selfSvc
                  else ownerId n;
                isService = selfSvc != null;
              }
              else resolveBackend ep.host ep.port;
          in
            lib.optional (res != null) {
              proxy = "svc/${n}/${proxySvc.key}";
              target = res.target;
              targetSys = res.sys;
              targetKey =
                if res.isService
                then lib.removePrefix "svc/${res.sys}/" res.target
                else null;
              router = r.router;
              hostnames = r.hostnames;
              backend = u;
            })
          r.backends)
        f.traefikRoutes))
    visibleNames;

    pubIndex = let
      step = acc: e:
        if e.targetKey == null
        then acc
        else let
          owner = ownerId e.targetSys;
          cur = acc.${owner}.${e.targetKey} or [];
        in
          acc
          // {
            ${owner} = (acc.${owner} or {}) // {${e.targetKey} = sortStrings (uniq (cur ++ e.hostnames));};
          };
    in
      lib.foldl' step {} routeEdges;

    # Names the reverse proxy publishes (Host(`x`) rules) resolve to the backend
    # they route to, so "vault.lan.example" means the vault service, not the proxy.
    publishedIndex = lib.foldl' (acc: e:
      lib.foldl' (a: h:
        if a ? ${lower h}
        then a
        else a // {${lower h} = {inherit (e) target targetSys targetKey;};})
      acc
      e.hostnames) {}
    routeEdges;

    # Resolve an endpoint host (ip, inventory name, or published hostname) + port.
    resolveEndpoint = host: port: let
      pub = publishedIndex.${lower host} or null;
    in
      if pub != null
      then {
        sys = pub.targetSys;
        target = pub.target;
        isService = pub.targetKey != null;
      }
      else resolveBackend host port;

    # ================================================================ relationships
    memberRels = lib.concatMap (n: let
      f = visible.${n};
      id = ownerId n;
      statics = staticV4 f;
      res = reservationFor f;
      fromStatic =
        map
        (a: {
          ip = a.address;
          iface = a.interface;
          source = "static";
        })
        statics;
      fromRes = lib.optional (res != null && statics == []) {
        ip = res.ip;
        iface = null;
        source = "dhcp-reservation";
      };
    in
      lib.concatMap
      (a: let
        nw = networkContaining a.ip;
      in
        lib.optional (nw != null) (mkRel {
          type = "member_of";
          from = id;
          to = nw.id;
          origin = {
            kind = "derived";
            ref = n;
          };
          attributes =
            {
              address = a.ip;
              addressSource = a.source;
              qualifier = a.ip;
            }
            // lib.optionalAttrs (a.iface != null) {interface = a.iface;};
        }))
      (fromStatic ++ fromRes))
    visibleNames;

    # VM tap -> host bridge attachment (L2, derived from networkd rules)
    attachRels = lib.concatMap (n: let
      f = visible.${n};
      host = primaryHostOf n;
    in
      lib.optionals (isVmSystem n && host != null)
      (lib.concatMap
        (gi: let
          att =
            if gi.id == null
            then null
            else tapAttachment host gi.id;
        in
          lib.optional (att != null && att.bridge != null) (mkRel {
            type = "attached_to";
            from = ownerId n;
            to = ownerId host;
            origin = {
              kind = "derived";
              ref = host;
              path = "systemd.network.networks.${att.rule}";
            };
            attributes = {
              bridge = att.bridge;
              tap = gi.id;
              qualifier = gi.id;
            };
          }))
        f.guestInterfaces))
    visibleNames;

    # Declared lookup shadowing: more than one .network file matches a tap with
    # a different bridge. networkd applies only the first, so flag it.
    shadowDiagnostics = lib.concatMap (n: let
      f = visible.${n};
      host = primaryHostOf n;
    in
      lib.optionals (isVmSystem n && host != null)
      (lib.concatMap
        (gi: let
          att =
            if gi.id == null
            then null
            else tapAttachment host gi.id;
        in
          lib.optional (att != null && att.shadowed != []) {
            level = "warning";
            code = "shadowed_network_match";
            subject = ownerId n;
            message = "tap ${gi.id} of ${n} matches several systemd.network.networks on ${host}; networkd applies only the first (${att.rule}, bridge ${toString att.bridge}) and ignores: ${lib.concatStringsSep ", " (map (s: "${s.rule} (bridge ${toString s.bridge})") att.shadowed)}";
          })
        f.guestInterfaces))
    visibleNames;

    # Reverse-proxy routing edges
    proxyRels =
      map
      (e:
        mkRel {
          type = "proxies_to";
          from = e.proxy;
          to = e.target;
          origin = {
            kind = "derived";
            path = "traefik.dynamicConfigOptions";
          };
          attributes = {
            router = e.router;
            hostnames = e.hostnames;
            qualifier = e.router;
          };
        })
      routeEdges;

    # Vault agent clients -> vault service
    vaultRels = lib.concatMap (n: let
      f = visible.${n};
      ep =
        if f.vaultAgentEnabled && f.vaultAddress != null
        then parseEndpoint f.vaultAddress
        else null;
      res =
        if ep == null
        then null
        else resolveEndpoint ep.host ep.port;
    in
      lib.optional (res != null && res.sys != n) (mkRel {
        type = "uses";
        from = ownerId n;
        to = res.target;
        origin = {
          kind = "derived";
          ref = n;
          path = "fmf.services.vault-agent.settings.vault.address";
        };
        attributes = {
          purpose = "secrets";
        };
      }))
    visibleNames;

    # DNS resolvers
    dnsRels = lib.concatMap (n: let
      f = visible.${n};
    in
      lib.concatMap (ns: let
        res = resolveEndpoint ns 53;
      in
        lib.optional (res != null && res.sys != n) (mkRel {
          type = "uses";
          from = ownerId n;
          to = res.target;
          origin = {
            kind = "derived";
            ref = n;
            path = "networking.nameservers";
          };
          attributes = {
            purpose = "dns";
            qualifier = ns;
          };
        }))
      (lib.filter net.isV4 f.nameservers))
    visibleNames;

    # Remote filesystems -> the NFS/etc. server
    mountRels = lib.concatMap (n: let
      f = visible.${n};
    in
      lib.concatMap
      (s:
        if s.kind != "remote-mount" || s.device == null
        then []
        else let
          m = builtins.match "([^:/]+):.*" s.device;
          res =
            if m == null
            then null
            else resolveEndpoint (builtins.head m) null;
        in
          lib.optional (res != null && res.sys != n) (mkRel {
            type = "mounts_from";
            from = ownerId n;
            to = res.target;
            origin = {
              kind = "derived";
              ref = n;
              path = "fileSystems.${s.mountPoint}";
            };
            attributes = {
              mountPoint = s.mountPoint;
              fsType = s.fsType;
              qualifier = s.mountPoint;
            };
          }))
      f.storage)
    visibleNames;

    # Explicit hint connections (physical links are only ever *declared*)
    resolveHintTarget = to:
      if to == null
      then null
      else if lib.hasPrefix "host/" to || lib.hasPrefix "vm/" to || lib.hasPrefix "device/" to
      then to
      else if visible ? ${to}
      then ownerId to
      else if deviceIds ? ${slug to}
      then "device/${slug to}"
      else null;
    deviceIds = lib.listToAttrs (map (r: lib.nameValuePair (lib.removePrefix "device/" r.id) true) deviceResources);

    hintConnections = lib.concatMap (n: let
      f = visible.${n};
      fromSys =
        map (c: {
          from = ownerId n;
          conn = c;
          owner = n;
          path = "fmf.services.circuit-breaker.hints.connections";
        })
        f.hints.connections;
      fromDev = lib.concatLists (lib.mapAttrsToList
        (dn: d:
          map (c: {
            from = "device/${slug dn}";
            conn = c;
            owner = n;
            path = "fmf.services.circuit-breaker.hints.devices.${dn}.connections";
          })
          d.connections)
        f.hints.devices);
    in
      fromSys ++ fromDev)
    visibleNames;

    connectRels = lib.concatMap (h: let
      to = resolveHintTarget h.conn.to;
    in
      lib.optional (to != null) (mkRel {
        type = "connects_to";
        from = h.from;
        inherit to;
        origin = {
          kind = "hint";
          ref = h.owner;
          path = h.path;
        };
        attributes = {
          connection = h.conn.type;
          bandwidthMbps = h.conn.bandwidthMbps;
          label = h.conn.label;
        };
      }))
    hintConnections;

    # ================================================================ diagnostics
    placementDiagnostics = lib.concatMap (n: let
      f = visible.${n};
      ps = placedHostsOf n;
    in
      (lib.optional (f.isGuest && ps == []) {
        level = "info";
        code = "unplaced_microvm";
        subject = "vm/${n}";
        message = "${n} is a MicroVM configuration but no host lists it in microvm.vms; it is reported but not attached to a host.";
      })
      ++ (lib.optional (lib.length ps > 1) {
        level = "warning";
        code = "duplicate_microvm_placement";
        subject = "vm/${n}";
        message = "${n} is listed in microvm.vms of several hosts (${lib.concatStringsSep ", " ps}); using ${builtins.head ps}.";
      }))
    visibleNames;

    missingVmDiagnostics = lib.concatMap (hn:
      lib.concatMap (vn:
        lib.optional (!(visible ? ${vn}))
        {
          level = "warning";
          code = "microvm_without_configuration";
          subject = "host/${hn}";
          message = "${hn} lists microvm.vms.${vn} but no such nixosConfiguration exists in this inventory; the VM is omitted.";
        }) (builtins.attrNames visible.${hn}.hostedVms))
    visibleNames;

    # The same address declared by several systems is a flake bug worth surfacing
    # (Circuit Breaker itself refuses duplicate IPs).
    duplicateAddressDiagnostics = lib.concatMap (ip: let
      owners = sortStrings (uniq addrIndex.${ip});
    in
      lib.optional (lib.length owners > 1) {
        level = "warning";
        code = "duplicate_address";
        subject = ip;
        message = "address ${ip} is declared by several systems: ${lib.concatStringsSep ", " owners}.";
      })
    (builtins.attrNames addrIndex);

    unmatchedReservations = let
      matchedMacs = lib.unique (lib.concatMap (n: systemMacs visible.${n}) visibleNames);
    in
      lib.filter (r: !(builtins.elem r.mac matchedMacs)) allReservations;

    unmatchedDevices = lib.optionals opts.includeUnmatchedReservations (map
      (r:
        mkRes {
          id = "device/dhcp-${slug r.mac}";
          type = "device";
          name =
            if r.hostname != null
            then r.hostname
            else r.mac;
          tags = ["source:dhcp-reservation"];
          origin = {
            kind = "derived";
            path = "fmf.router.zones.zones.${r.zone}.dhcp.staticLeases";
          };
          attributes = {
            primaryAddress = r.ip;
            addressSource = "dhcp-reservation";
            mac = r.mac;
            zone = r.zone;
          };
        })
      unmatchedReservations);

    # ================================================================ assemble
    systemResources = map systemResource visibleNames;
    allResources =
      sortBy (r: r.id) (systemResources ++ deviceResources ++ unmatchedDevices ++ networkResources ++ serviceResources ++ containerResources);

    resourceIds = map (r: r.id) allResources;
    resourceIdSet = lib.genAttrs resourceIds (_: true);

    # Drop relationships whose endpoints are not in the inventory.
    allRelationships = let
      rels = memberRels ++ attachRels ++ proxyRels ++ vaultRels ++ dnsRels ++ mountRels ++ connectRels;
      valid = lib.filter (r: resourceIdSet ? ${r.from} && resourceIdSet ? ${r.to}) rels;
      byId = lib.listToAttrs (map (r: lib.nameValuePair r.id r) valid);
    in
      lib.attrValues byId;

    # ---- monitors (declared checks; never runtime state)
    mon = opts.monitoring;
    monitorExcluded = id: anyGlob mon.exclude id;

    hostMonitors = lib.optionals mon.enable (lib.concatMap (r: let
      enabledHint = r.attributes.monitoringEnabled or null;
      addr = r.attributes.primaryAddress or null;
      addrSource = r.attributes.addressSource or null;
      placed = (r.attributes.placement or "placed") != "unplaced";
    in
      lib.optionals (builtins.elem r.type ["host" "vm" "device"] && addr != null && addrSource != "hostname" && enabledHint != false && placed && !(monitorExcluded r.id))
      (
        (lib.optional mon.icmp {
          id = "mon/${r.id}/icmp";
          target = r.id;
          checkType = "icmp";
          host = addr;
          config = {};
          intervalSecs = mon.intervalSecs;
          name = "${r.name} reachability";
        })
        ++ (lib.optionals mon.ssh (let
          ssh = lib.findFirst (s: s.parent == r.id && s.attributes.kind == "remote-access") null serviceResources;
          port =
            if ssh == null || ssh.attributes.ports == []
            then null
            else (builtins.head ssh.attributes.ports).port;
          expo =
            if ssh == null || ssh.attributes.ports == []
            then null
            else (builtins.head ssh.attributes.ports).exposure;
        in
          lib.optional (port != null && expo != "closed") {
            id = "mon/${r.id}/ssh";
            target = r.id;
            checkType = "tcp";
            host = addr;
            config = {port = port;};
            intervalSecs = mon.intervalSecs;
            name = "${r.name} ssh";
          }))
      ))
    allResources);

    serviceMonitors = lib.optionals mon.enable (lib.concatMap (r: let
      a = r.attributes;
      addr = a.address or null;
      ports = a.ports or [];
      first =
        if ports == []
        then null
        else builtins.head ports;
      hostnames = a.publishedHostnames or [];
      owner = lib.findFirst (o: o.id == r.parent) null systemResources;
      ownerEnabled = owner != null && (owner.attributes.monitoringEnabled or null) != false && (owner.attributes.placement or "placed") != "unplaced" && (owner.attributes.addressSource or null) != "hostname";
      kind = a.kind or "application";
      tcp =
        lib.optional (mon.tcp or true && first != null && first.exposure != "closed" && builtins.elem kind mon.tcpKinds && first.protocol == "tcp")
        {
          id = "mon/${r.id}/tcp-${toString first.port}";
          target = r.id;
          checkType = "tcp";
          host = addr;
          config = {port = first.port;};
          intervalSecs = mon.intervalSecs;
          name = "${r.name} tcp/${toString first.port}";
        };
      http =
        lib.optional (mon.http && hostnames != [])
        {
          id = "mon/${r.id}/http";
          target = r.id;
          checkType = "http";
          host = builtins.head hostnames;
          config = {
            url = "https://${builtins.head hostnames}/";
            method = "GET";
            verify_tls = mon.httpVerifyTls;
            accepted_statuses = ["200-399" "401" "403"];
            follow_redirects = true;
          };
          intervalSecs = mon.intervalSecs;
          name = "${r.name} https";
        };
      dns =
        lib.optional (kind == "dns" && mon.dnsQueryName != null && addr != null && first != null)
        {
          id = "mon/${r.id}/dns";
          target = r.id;
          checkType = "dns";
          host = addr;
          config = {
            record_type = "A";
            resolver = addr;
            port = first.port;
          };
          query = mon.dnsQueryName;
          intervalSecs = mon.intervalSecs;
          name = "${r.name} dns";
        };
    in
      lib.optionals (r.type == "service" && ownerEnabled && addr != null && !(monitorExcluded r.id))
      (tcp ++ http ++ dns))
    serviceResources);

    monitors = sortBy (m: m.id) (map (m: nonNull m) (hostMonitors ++ serviceMonitors));

    diagnostics = sortBy (d: "${d.level}/${d.code}/${d.subject}/${d.message}") (
      placementDiagnostics ++ missingVmDiagnostics ++ shadowDiagnostics ++ duplicateAddressDiagnostics
    );

    # Duplicate ids are a bug in this exporter or a hint collision; surface them.
    dupIds = let
      counts = lib.foldl' (acc: id: acc // {${id} = (acc.${id} or 0) + 1;}) {} resourceIds;
    in
      lib.attrNames (lib.filterAttrs (_: c: c > 1) counts);
    duplicateDiagnostics =
      map (id: {
        level = "error";
        code = "duplicate_id";
        subject = id;
        message = "resource id ${id} is produced more than once; the first definition wins.";
      })
      dupIds;
    dedupedResources = let
      step = acc: r:
        if acc.seen ? ${r.id}
        then acc
        else {
          seen = acc.seen // {${r.id} = true;};
          out = acc.out ++ [r];
        };
    in
      (lib.foldl' step {
          seen = {};
          out = [];
        }
        allResources).out;
  in {
    schemaVersion = schemaVersion;
    kind = "circuit-breaker-inventory";
    semantics = "declared";
    generator = {
      name = "fmf-circuit-breaker-exporter";
      version = generatorVersion;
    };
    source = nonNull {
      name = flake.name or null;
      revision = flake.rev or null;
      dirty = flake.dirty or null;
      lastModified = flake.lastModified or null;
      systems = visibleNames;
    };
    resources = dedupedResources;
    relationships = sortBy (r: r.id) allRelationships;
    monitors = monitors;
    diagnostics = sortBy (d: "${d.level}/${d.code}/${d.subject}/${d.message}") (diagnostics ++ duplicateDiagnostics);
  };
in {
  inherit mkInventory schemaVersion defaultOptions;
}
