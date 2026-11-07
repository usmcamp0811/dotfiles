# Regression tests for the derivation rules; no host evaluation needed.
#   nix-instantiate --eval --strict lib/vault-access/tests.nix   # -> "ok"; any failure throws
{pkgs ? import <nixpkgs> {}}: let
  va = (import ./default.nix {inherit (pkgs) lib;}).vaultAccess;
  c = fn: path: {inherit fn path;};
  host = svcs: {
    enabled = true;
    services = svcs;
  };
  r = va.render {
    mount = "secret/campground";
    hosts = {
      a = host {
        MixedCase = [(c "secret" "secret/campground/foo")];
        pki = [(c "secret" "grpc-farm-pki/issue/grpc-farm") (c "secret" "grpc-farm-pki/cert/ca")];
        explicit = [(c "secret" "secret/campground/data/llama-cpp")];
        outside = [(c "secret" "secret/other/x")];
        shared = [(c "secret" "secret/campground/one")];
      };
      b = host {shared = [(c "secret" "secret/campground/one") (c "secret" "secret/campground/two")];};
      off = {
        enabled = false;
        services = {};
      };
    };
  };
  has = s: sub: pkgs.lib.hasInfix sub s;

  # expected source addresses: leases joined to hosts
  leases = [
    {mac = "02:00:00:00:00:21"; ip = "10.8.0.4"; hostname = "lan-traefik";}
    {mac = "02:00:00:00:00:E0"; ip = "10.8.0.10"; hostname = "airflow";}
    {mac = "aa:bb:cc:00:00:01"; ip = "10.8.0.89"; hostname = "lucas";}
    {mac = "aa:bb:cc:00:00:02"; ip = "10.8.10.7"; hostname = "lucas-wifi";}
    {mac = "aa:bb:cc:00:00:03"; ip = "10.8.0.50"; hostname = "ATA-NUC";}
    {mac = "aa:bb:cc:00:00:04"; ip = "10.8.0.60"; hostname = "butler";}
  ];
  ipHosts = {
    vm-lan-traefik.macs = ["02:00:00:00:00:21"];
    vm-airflow-server.macs = ["02:00:00:00:00:e0"];
    lucas.macs = [];
    vm-k8s-worker-butler.macs = [];
    blue-ridge.macs = [];
  };
  e = va.expectedIps {
    hosts = ipHosts;
    inherit leases;
    extra = {blue-ridge = ["10.8.0.1"]; lucas = ["10.8.0.89"];};
  };
  rIps = va.render {hosts = r_hosts; inherit leases;};
  r_hosts = ipHosts // {a = {enabled = false; services = {}; macs = [];};};
  checks = [
    # a MicroVM is matched by MAC (case-insensitively); a legacy lease name is an identity of its own
    ["vm by mac" (e.vm-lan-traefik == ["10.8.0.4"])]
    ["mac case ignored" (e.vm-airflow-server == ["10.8.0.10"])]
    ["legacy lease name resolves" (e.lan-traefik == ["10.8.0.4"] && e.ata-nuc == ["10.8.0.50"])]
    # a physical host gets every network it is leased on, and the extra is merged without duplicates
    ["host gets eth and wifi" (e.lucas == ["10.8.0.89" "10.8.10.7"])]
    # a vm- host with no lease stays unmatched and does not pick up the physical host sharing the tail of its name
    ["vm- with no lease stays unmatched" (!(e ? vm-k8s-worker-butler))]
    # what leases cannot say comes from the override
    ["extra for the router" (e.blue-ridge == ["10.8.0.1"])]
    ["mapping file text" (has rIps.ipsMapping "\"lucas\" = [\"10.8.0.89\" \"10.8.10.7\"];")]
    # Vault lowercases policy names; files must already be lowercase
    ["lowercased name" (r.policies ? "svc-mixedcase")]
    # KV v2: template path gets the data/ segment, plus mount discovery
    ["kv data path" (has r.policies.svc-mixedcase ''path "secret/campground/data/foo"'')]
    ["mount discovery" (has r.policies.svc-mixedcase ''path "sys/internal/ui/mounts/secret/campground/foo"'')]
    # a template that already says data/ is not rewritten to data/data
    ["no data/data" (!(has r.policies.svc-explicit "data/data"))]
    ["explicit data kept" (has r.policies.svc-explicit ''path "secret/campground/data/llama-cpp"'')]
    # PKI: issue is update, ca is read
    ["pki issue" (has r.policies.svc-pki "path \"grpc-farm-pki/issue/grpc-farm\" {\n  capabilities = [\"update\"]")]
    ["pki ca" (has r.policies.svc-pki "path \"grpc-farm-pki/cert/ca\" {\n  capabilities = [\"read\"]")]
    # outside the mount and not PKI: visible, grants nothing
    ["unresolved grants nothing" (has r.policies.svc-outside "# UNRESOLVED" && !(has r.policies.svc-outside "capabilities"))]
    # same service name, different secrets => two policies, each host only gets its own
    ["variants split" (r.policies ? "svc-shared--one" && r.policies ? "svc-shared--one-two")]
    ["host a variant" (r.hosts.a == ["svc-explicit" "svc-mixedcase" "svc-outside" "svc-pki" "svc-shared--one"])]
    ["host b variant" (r.hosts.b == ["svc-shared--one-two"])]
    ["disabled host absent" (!(r.hosts ? off))]
  ];
  failed = builtins.filter (x: !(builtins.elemAt x 1)) checks;
in
  if failed == []
  then "ok"
  else throw "vault-access tests failed: ${builtins.concatStringsSep ", " (map (x: builtins.head x) failed)}"
