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
  checks = [
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
