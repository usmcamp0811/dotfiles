# The host record: one declaration per machine, read by lib.fmf.fleet.
#
# This module only DECLARES data (and a shared zone catalogue). It has no effect on the machine
# that declares it; consumers derive leases, DNS, port forwards, Vault roles, MicroVM hosting and
# boot order from the records of the whole fleet. A host with `kind = null` (the default) is not
# managed by the model yet and is ignored. Specification: docs/HOST-MODEL.md.
{
  lib,
  config,
  options,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.host;

  macType = types.strMatching "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}";

  interfaceType = types.submodule {
    options = {
      mac = mkOpt (types.nullOr macType) null "MAC address. Required for a MicroVM, and for any interface that gets a lease.";
      ip = mkOpt (types.nullOr types.str) null "IPv4 address. null = dynamic: no lease is generated and nothing is expected from it.";
      zone = mkOption {
        type = types.str;
        description = "Zone id from `fmf.network.zones`. Selects subnet, VLAN, gateway and DNS domain.";
      };
      attach = mkOpt (types.enum ["tap" "macvtap"]) "tap" "MicroVM only: how the interface reaches the network.";
      static =
        mkOpt types.bool (cfg.kind == "microvm")
        "Whether the machine configures this address itself. Defaults to true for a MicroVM; a physical host keeps DHCP against a generated lease.";
      primary = mkOpt (types.nullOr types.bool) null "Which interface is the host's primary address (DNS, port forwards). null = it is the only one.";
      leaseName =
        mkOpt (types.nullOr types.str) null
        "Name in the DHCP lease. Default: the host name without `vm-`, plus `-<interface>` when it is not the primary one.";
    };
  };

  storageType = types.submodule {
    options = {
      mountPoint = mkOption {
        type = types.str;
        description = "Where the share appears in the guest.";
      };
      hostPath = mkOpt (types.nullOr types.str) null "Directory on the hypervisor. Default: /persist/vm-data/<vm>/<name>.";
      tag = mkOpt (types.nullOr types.str) null "virtiofs tag. Default: the entry name.";
      mode = mkOpt types.str "0755" "Mode of the host directory.";
      createDirectory = mkOpt types.bool true "Generate a tmpfiles rule for the host directory. Turn it off for a path that already exists and is owned by something else (a user's home, a ZFS dataset): a `d` rule resets the mode and owner of a directory that is already there.";
      owner = mkOpt types.str "root" "Owner of the host directory (a user name or numeric id; the guest sees it through virtiofs).";
      group = mkOpt types.str "root" "Group of the host directory.";
      readOnly = mkOpt types.bool false "Export the share read-only.";
      shared = mkOpt types.bool false "The host path is deliberately shared with another VM (suppresses the collision check).";
      order =
        mkOpt types.int 100
        "Position among this VM's storage shares (lower first; ties sort by name). Shares are part of the VM's runner, so a different order restarts the VM on deploy: match the existing order when migrating.";
    };
  };

  exposeType = types.submodule {
    options = {
      port = mkOption {
        type = types.port;
        description = "Port on the router.";
      };
      destPort = mkOpt (types.nullOr types.port) null "Port on the host, if different.";
      proto = mkOpt (types.enum ["tcp" "udp"]) "tcp" "Transport protocol.";
      description = mkOpt types.str "" "What this forward is for.";
    };
  };

  zoneType = types.submodule {
    options = {
      subnet = mkOption {
        type = types.str;
        example = "192.168.50.0/24";
        description = "Zone subnet (IPv4 CIDR).";
      };
      gateway = mkOpt (types.nullOr types.str) null "Gateway address.";
      vlanId = mkOpt (types.nullOr types.int) null "VLAN id; null = the native, untagged network.";
      dhcpRange = mkOpt (types.nullOr (types.submodule {
        options = {
          start = mkOption {
            type = types.str;
            description = "First address of the DHCP pool.";
          };
          end = mkOption {
            type = types.str;
            description = "Last address of the DHCP pool.";
          };
        };
      })) null "The DHCP pool. Used to warn about a static address inside the pool that no lease reserves.";
      dns = mkOpt (types.listOf types.str) [] "DNS servers handed to hosts in this zone.";
      hostDomain =
        mkOpt (types.nullOr types.str) null
        "Domain under which HOST names resolve, e.g. lan-hosts.aicampground.com. Keep it apart from the domain service names use, so a host called vault does not collide with the service vault.<service domain>.";
      description = mkOpt types.str "" "What this zone is for.";
    };
  };
in {
  options.fmf.network.zones = mkOpt (types.attrsOf zoneType) {} ''
    The fleet's network zones, defined once and shared by every host (set it in a module that all hosts
    import). Host records refer to a zone by its id here; the router's zone configuration should be built
    from this same catalogue so the two cannot disagree.
  '';

  options.fmf.host = {
    kind = mkOpt (types.nullOr (types.enum ["physical" "microvm"])) null "What this machine is. null = not managed by the host model yet.";

    lifecycle = mkOpt (types.enum ["active" "standby" "retired"]) "active" ''
      active: everything is generated. standby: provisioned (lease, role, DNS, placement) but not started,
      with no port forwards. retired: nothing is generated, its Vault role is reported for deletion, and
      anything that still references it is an error. A retired host stays in the repository as a record.
    '';
    retired = {
      since = mkOpt (types.nullOr types.str) null "When it was retired.";
      reason = mkOpt (types.nullOr types.str) null "Why.";
      replacedBy = mkOpt (types.nullOr types.str) null "The host that took over.";
    };

    network.interfaces = mkOpt (types.attrsOf interfaceType) {} "Network interfaces, by name. A host may have several, each in its own zone.";

    placement = {
      runsOn = mkOpt (types.nullOr types.str) null "MicroVM only: the name of the physical host that runs it.";
      autostart = mkOpt types.bool true "Start with the hypervisor (only applies while the lifecycle is active).";
      restartIfChanged =
        mkOpt (types.nullOr types.bool) null
        "null = do not set it (the microvm default applies). Leave null for VMs that must never restart on deploy, such as the Vault VM.";
      hostDirectories =
        mkOpt (types.enum ["managed" "external"]) "managed"
        "managed: the hypervisor's directories for this VM are generated (tmpfiles). external: they exist already and are not generated, because a tmpfiles `d` rule resets the mode and owner of a directory that is already there.";
    };

    derive = mkOpt types.bool false ''
        MicroVM only. Take this VM's `microvm.shares` and `microvm.writableStoreOverlay` from this record, and
        have its hypervisor generate the VM's stanza, directories and start ordering (the committed
        `microvms` file written by `fleet`). Off by default so a VM is converted deliberately, one at a time:
        turn it on in the same change that deletes the hand-written shares and hypervisor lines.
      '';

    nixStore =
      mkOpt (types.enum ["persistent" "volatile" "none"]) "persistent"
      ''
        MicroVM only. How the guest's Nix store is writable.
        persistent: a writable overlay backed by /persist/vm-stores/<vm>/nix-store (the `rw-store` share).
        volatile: a writable overlay with no share of its own.
        none: the store is read-only.
      '';

    standardShares = {
      rootPassword = mkOpt types.bool true "Share the hypervisor's /persist/system/secrets as /run/secrets (the root password hash).";
      vaultAgent = mkOpt (types.nullOr types.bool) null "Share the Vault credentials directory. null = when the guest enables fmf.services.vault-agent.";
    };

    storage = mkOpt (types.attrsOf storageType) {} "Data directories shared into a MicroVM: one entry yields the guest share and the host directory.";

    boot = {
      after = mkOpt (types.listOf types.str) [] "MicroVMs on the same hypervisor that must start first. Ordering across machines is not expressible and is an error.";
      hostUnits = mkOpt (types.listOf types.str) [] "Units on the hypervisor this VM must start after, e.g. tang.socket.";
    };

    dns = {
      names = mkOpt (types.listOf types.str) [] "Extra DNS names that resolve to this host's primary address.";
      addAliases = mkOpt types.bool true "Also create the host name and the lease name, short and as FQDN.";
    };

    expose = mkOpt (types.listOf exposeType) [] "Ports to forward from the router to this host's primary address.";

    vault = {
      role = mkOpt (types.nullOr types.str) null "AppRole name. Default: the host name.";
      extraPolicies = mkOpt (types.listOf types.str) [] "Policies for access no vault-agent template implies. The svc-* policies are derived, never listed here.";
      aliases = mkOpt (types.listOf types.str) [] "Legacy role names still used by this host. Each carries the same policies and expected addresses.";
    };

    topology = {
      role = mkOpt (types.nullOr types.str) null "router, hypervisor, nas, ...";
      location = mkOpt (types.nullOr types.str) null "Physical location.";
      rack = mkOpt (types.nullOr types.str) null "Rack position.";
      tags = mkOpt (types.listOf types.str) [] "Extra classification tags.";
    };
  };

  # A MicroVM that opts in (`derive`) gets its shares and store overlay from its own record. The same pure
  # functions give its hypervisor the matching directories, so the two sides cannot disagree. Nothing else
  # in this module has an effect on the machine.
  #
  # The `microvm` options exist only on machines that import the microvm guest module, and the module
  # system reports a definition of a missing option even under `mkIf false`. So the attributes are only
  # written where the option is declared; a physical host never sees them.
  config = let
    active = cfg.kind == "microvm" && cfg.derive;
    fl = (import ../../../../lib/fleet/default.nix {inherit lib;}).fleet;
    self = fl.extract config.networking.hostName config;
    overlay = fl.overlayOf self;
  in
    optionalAttrs (options ? microvm && options.microvm ? shares && options.microvm ? writableStoreOverlay) {
      microvm.shares = mkIf active (fl.sharesOf self);
      microvm.writableStoreOverlay = mkIf (active && overlay != null) overlay;
    };
}
