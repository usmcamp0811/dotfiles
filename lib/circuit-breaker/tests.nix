# Pure-Nix tests for the Circuit Breaker inventory exporter.
#
# Usage:
#   nix eval --impure --json --expr '(import ./lib/circuit-breaker/tests.nix { lib = (builtins.getFlake "nixpkgs").lib; }).failures'
#
# The checks/circuit-breaker-inventory flake check turns a non-empty `failures`
# list into a build failure. Fixtures are plain attrsets shaped like
# `nixosConfigurations.<name>`, so no NixOS evaluation is needed and every
# unsupported/throwing structure can be injected deliberately.
{lib}: let
  exporter = import ./inventory.nix {inherit lib;};

  fixture = config: {
    inherit config;
    pkgs.stdenv.hostPlatform.system = "x86_64-linux";
  };

  zones = {
    lan = {
      vlanId = null;
      subnet = "10.8.0.0/24";
      gateway = "10.8.0.1";
      dhcp.staticLeases = [
        {
          mac = "02:00:00:00:00:10";
          ip = "10.8.0.3";
          hostname = "vault";
        }
        {
          mac = "02:00:00:00:00:99";
          ip = "10.8.0.99";
          hostname = "printer";
        }
      ];
    };
    k8s = {
      vlanId = 40;
      subnet = "10.8.40.0/24";
      gateway = "10.8.40.1";
      dhcp.staticLeases = [];
    };
  };

  hostA = {
    networking.hostName = "alpha";
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [22 443];
      allowedUDPPorts = [];
    };
    services.openssh = {
      enable = true;
      ports = [22];
    };
    systemd.network.netdevs."10-br0".netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
    systemd.network.netdevs."20-vlan40".netdevConfig = {
      Kind = "vlan";
      Name = "br0.40";
    };
    systemd.network.netdevs."20-vlan40".vlanConfig.Id = 40;
    systemd.network.networks."10-br0" = {
      matchConfig.Name = "br0";
      networkConfig.Address = "10.8.0.20/24";
      networkConfig.Gateway = "10.8.0.1";
      vlan = ["br0.40"];
    };
    systemd.network.networks."30-taps" = {
      matchConfig.Name = "vm-*";
      networkConfig.Bridge = "br0";
    };
    microvm.vms = {
      vm-vault.autostart = true;
      vm-web.autostart = false;
      vm-ghost = {};
    };
    fmf.router.zones.zones = zones;
    fmf.services.traefik = {
      enable = true;
      dynamicConfigOptions.http = {
        routers.vault = {
          rule = "Host(`vault.lan.example`)";
          service = "vault";
        };
        services.vault.loadBalancer.servers = [{url = "http://10.8.0.3:8200";}];
      };
    };
    fmf.services.circuit-breaker.hints = {
      location = "rack-1";
      connections = [
        {
          to = "core-switch";
          type = "ethernet";
          bandwidthMbps = 10000;
        }
      ];
      devices.core-switch = {
        displayName = "Core switch";
        role = "switch";
        address = "10.8.0.2";
        location = "rack-1";
      };
    };
  };

  vmVault = {
    networking.hostName = "vm-vault";
    microvm = {
      hypervisor = "qemu";
      vcpu = 2;
      mem = 2047;
      interfaces = [
        {
          type = "tap";
          id = "vm-vault";
          mac = "02:00:00:00:00:10";
        }
      ];
      shares = [
        {
          proto = "virtiofs";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
        {
          proto = "virtiofs";
          source = "/persist/vm-data/vm-vault/vault";
          mountPoint = "/var/lib/vault";
        }
      ];
    };
    fmf.services.vault = {
      enable = true;
      port = 8200;
    };
    # Private material must never be exported.
    fmf.services.vault-agent = {
      enable = true;
      settings.vault.secret-id = "/run/secrets/very-secret";
    };
  };

  vmWeb = {
    networking.hostName = "vm-web";
    microvm = {
      hypervisor = "qemu";
      interfaces = [
        {
          type = "tap";
          id = "vm-web";
          mac = "02:00:00:00:00:11";
        }
      ];
      shares = [];
    };
    systemd.network.networks."20-lan0" = {
      matchConfig.Name = "lan0";
      address = ["10.8.0.11/24"];
    };
    fmf.services.searx = {
      enable = true;
      port = 8081;
    };
    fmf.services.vault-agent = {
      enable = true;
      settings.vault.address = "http://10.8.0.3:8200";
    };
    services.postgresql.enable = true;
  };

  vmOrphan = {
    networking.hostName = "vm-orphan";
    microvm = {
      hypervisor = "qemu";
      interfaces = [];
      shares = [];
    };
  };

  # A host whose options throw when read: must degrade, not abort.
  hostBroken = {
    networking.hostName = "broken";
    services.postgresql.enable = throw "removed option";
    networking.firewall.allowedTCPPorts = throw "boom";
    systemd.network.networks."10-x" = {
      matchConfig.Name = throw "boom";
    };
  };

  hostHidden = {
    networking.hostName = "hidden";
    fmf.services.circuit-breaker.hints.ignore = true;
  };

  hostB = {
    networking.hostName = "bravo";
    microvm.vms.vm-web = {};
    networking.interfaces.eno1.ipv4.addresses = [
      {
        address = "192.168.77.5";
        prefixLength = 24;
      }
    ];
  };

  systems = {
    alpha = fixture hostA;
    bravo = fixture hostB;
    vm-vault = fixture vmVault;
    vm-web = fixture vmWeb;
    vm-orphan = fixture vmOrphan;
    broken = fixture hostBroken;
    hidden = fixture hostHidden;
  };

  inv = exporter.mkInventory {
    nixosConfigurations = systems;
    flake = {
      name = "fixture";
      rev = "abc123";
    };
  };

  byId = lib.listToAttrs (map (r: lib.nameValuePair r.id r) inv.resources);
  relIds = map (r: r.id) inv.relationships;
  has = id: byId ? ${id};
  diagCodes = map (d: d.code) inv.diagnostics;
  monIds = map (m: m.id) inv.monitors;

  # Variations for stability tests.
  invWith = overrides:
    exporter.mkInventory {
      nixosConfigurations = systems // overrides;
      flake = {name = "fixture";};
    };

  resJson = i: id: builtins.toJSON ((lib.listToAttrs (map (r: lib.nameValuePair r.id r) i.resources)).${id} or null);

  unrelatedChange = invWith {
    bravo = fixture (hostB // {networking.firewall.allowedTCPPorts = [8080];});
  };
  ipChange = invWith {
    vm-web = fixture (vmWeb
      // {
        systemd.network.networks."20-lan0" = {
          matchConfig.Name = "lan0";
          address = ["10.8.0.55/24"];
        };
      });
  };
  removedVm = invWith {
    alpha = fixture (hostA // {microvm.vms = {vm-vault = {};};});
  };
  noOptional = exporter.mkInventory {
    nixosConfigurations.bare = {config = {};};
  };

  tests = {
    schemaVersionIsOne = {
      expr = inv.schemaVersion;
      expected = 1;
    };
    declaredSemantics = {
      expr = inv.semantics;
      expected = "declared";
    };
    sourceRevisionRecorded = {
      expr = inv.source.revision;
      expected = "abc123";
    };
    hostsAndVms = {
      expr = map (r: r.id) (lib.filter (r: r.type == "host" || r.type == "vm") inv.resources);
      expected = ["host/alpha" "host/bravo" "host/broken" "vm/vm-orphan" "vm/vm-vault" "vm/vm-web"];
    };
    hiddenSystemExcluded = {
      expr = has "host/hidden";
      expected = false;
    };
    vmParentIsHost = {
      expr = byId."vm/vm-vault".parent;
      expected = "host/alpha";
    };
    duplicatePlacementUsesFirstAndWarns = {
      expr = [byId."vm/vm-web".parent (lib.elem "duplicate_microvm_placement" diagCodes)];
      expected = ["host/alpha" true];
    };
    unplacedVmHasNoParent = {
      expr = [byId."vm/vm-orphan".parent byId."vm/vm-orphan".attributes.placement];
      expected = [null "unplaced"];
    };
    missingVmConfigurationReported = {
      expr = [(has "vm/vm-ghost") (lib.elem "microvm_without_configuration" diagCodes)];
      expected = [false true];
    };
    staticAddressAndNetwork = {
      expr = [byId."host/alpha".attributes.primaryAddress byId."host/alpha".attributes.addressSource];
      expected = ["10.8.0.20" "static"];
    };
    dhcpReservationAddress = {
      expr = [byId."vm/vm-vault".attributes.primaryAddress byId."vm/vm-vault".attributes.addressSource];
      expected = ["10.8.0.3" "dhcp-reservation"];
    };
    staticVmAddressFromNetworkdList = {
      expr = byId."vm/vm-web".attributes.primaryAddress;
      expected = "10.8.0.11";
    };
    zoneNetworksPresent = {
      expr = [(has "net/lan") (has "net/k8s") byId."net/k8s".attributes.vlanId];
      expected = [true true 40];
    };
    derivedNetworkForUnzonedSubnet = {
      expr = byId."net/192.168.77.0-24".origin.kind;
      expected = "derived";
    };
    membershipIsL3NotCable = {
      expr = [
        (lib.elem "rel/member_of/host/alpha/net/lan/10.8.0.20" relIds)
        (lib.any (r: r.type == "connects_to" && r.origin.kind != "hint") inv.relationships)
      ];
      expected = [true false];
    };
    bridgeAndVlanInterfaces = {
      expr = map (i: [i.name i.kind (i.vlanId or null) (i.parent or null)]) byId."host/alpha".attributes.interfaces;
      expected = [["br0" "bridge" null null] ["br0.40" "vlan" 40 "br0"]];
    };
    tapAttachmentDerived = {
      expr =
        (byId."vm/vm-vault".attributes.guestInterfaces)
        == [
          {
            attachedTo = "br0";
            mac = "02:00:00:00:00:10";
            tapId = "vm-vault";
            type = "tap";
          }
        ];
      expected = true;
    };
    attachedToRelationship = {
      expr = lib.elem "rel/attached_to/vm/vm-vault/host/alpha/vm-vault" relIds;
      expected = true;
    };
    virtiofsShareIsStorageButStoreIsNot = {
      expr = map (s: s.mountPoint) byId."vm/vm-vault".attributes.storage;
      expected = ["/var/lib/vault"];
    };
    servicesClassified = {
      expr = [
        byId."svc/vm-vault/vault".attributes.kind
        byId."svc/vm-web/searx".attributes.kind
        byId."svc/vm-web/postgresql".attributes.kind
        byId."svc/alpha/ssh".attributes.kind
      ];
      expected = ["secrets" "application" "database" "remote-access"];
    };
    vaultAgentIsNotAService = {
      expr = has "svc/vm-vault/vault-agent";
      expected = false;
    };
    serviceExposureFromFirewall = {
      expr = (builtins.head byId."svc/alpha/ssh".attributes.ports).exposure;
      expected = "open";
    };
    proxyEdgeResolvesToService = {
      expr = lib.elem "rel/proxies_to/svc/alpha/traefik/svc/vm-vault/vault/vault" relIds;
      expected = true;
    };
    publishedHostnameRecorded = {
      expr = byId."svc/vm-vault/vault".attributes.publishedHostnames;
      expected = ["vault.lan.example"];
    };
    vaultClientEdgeUsesPublishedService = {
      expr = lib.elem "rel/uses/vm/vm-web/svc/vm-vault/vault" relIds;
      expected = true;
    };
    hintDeviceAndConnection = {
      expr = [byId."device/core-switch".name (lib.elem "rel/connects_to/host/alpha/device/core-switch" relIds)];
      expected = ["Core switch" true];
    };
    throwingOptionsDegrade = {
      expr = [(has "host/broken") (byId."host/broken".attributes.firewall.openTcpPorts)];
      expected = [true []];
    };
    unplacedVmNotMonitored = {
      expr = lib.any (m: m.target == "vm/vm-orphan") inv.monitors;
      expected = false;
    };
    hostIcmpAndSshMonitors = {
      expr = [(lib.elem "mon/host/alpha/icmp" monIds) (lib.elem "mon/host/alpha/ssh" monIds)];
      expected = [true true];
    };
    httpMonitorOnlyForPublishedServices = {
      expr = [(lib.elem "mon/svc/vm-vault/vault/http" monIds) (lib.elem "mon/svc/vm-web/searx/http" monIds)];
      expected = [true false];
    };
    noSecretsExported = {
      expr = lib.hasInfix "very-secret" (builtins.toJSON inv);
      expected = false;
    };
    noRuntimeStateClaimed = {
      expr = lib.all (r: r.state == "declared") inv.resources;
      expected = true;
    };
    idsUniqueAndSorted = {
      expr = let
        ids = map (r: r.id) inv.resources;
      in [(ids == lib.sort (a: b: a < b) ids) (lib.length ids == lib.length (lib.unique ids))];
      expected = [true true];
    };
    deterministicOutput = {
      expr = builtins.toJSON inv == builtins.toJSON (invWith {} // {source = inv.source;});
      expected = true;
    };
    idsStableAcrossUnrelatedChange = {
      expr = map (id: resJson inv id == resJson unrelatedChange id) ["host/alpha" "vm/vm-vault" "vm/vm-web" "svc/vm-web/searx"];
      expected = [true true true true];
    };
    ipChangeKeepsIdChangesAddress = {
      expr = [
        (has "vm/vm-web")
        ((lib.listToAttrs (map (r: lib.nameValuePair r.id r) ipChange.resources))."vm/vm-web".attributes.primaryAddress)
      ];
      expected = [true "10.8.0.55"];
    };
    removedFromAllHostsBecomesUnplaced = {
      expr = let
        i = invWith {
          alpha = fixture (hostA // {microvm.vms = {vm-vault = {};};});
          bravo = fixture (hostB // {microvm.vms = {};});
        };
      in
        (lib.listToAttrs (map (r: lib.nameValuePair r.id r) i.resources))."vm/vm-web".attributes.placement;
      expected = "unplaced";
    };
    absentOptionalValuesTolerated = {
      expr = map (r: r.id) noOptional.resources;
      expected = ["host/bare"];
    };
    emptyInputIsEmptyInventory = {
      expr = (exporter.mkInventory {nixosConfigurations = {};}).resources;
      expected = [];
    };
    excludeSystemsOption = {
      expr = let
        i = exporter.mkInventory {
          nixosConfigurations = systems;
          options.excludeSystems = ["bravo"];
        };
      in
        lib.any (r: r.id == "host/bravo") i.resources;
      expected = false;
    };
  };

  failures = lib.filter (t: t.result != t.expected) (lib.mapAttrsToList
    (name: t: {
      inherit name;
      result = t.expr;
      expected = t.expected;
    })
    tests);
in {
  inherit tests failures inv;
  count = lib.length (builtins.attrNames tests);
}
