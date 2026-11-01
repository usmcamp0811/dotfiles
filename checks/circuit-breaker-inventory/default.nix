# Exporter tests: pure-Nix fixtures -> inventory, asserted at evaluation time, then
# the produced document is validated by the real reconciler (`--validate`), which
# also proves the Nix and Python halves agree on schema v1.
{
  pkgs,
  lib,
  ...
}: let
  t = import ../../lib/circuit-breaker/tests.nix {inherit lib;};
  inventory = pkgs.writeText "fixture-inventory.json" (builtins.toJSON t.inv);
in
  assert lib.assertMsg (t.failures == []) "circuit-breaker exporter tests failed: ${builtins.toJSON t.failures}";
    pkgs.runCommand "circuit-breaker-inventory-check" {
      nativeBuildInputs = [pkgs.fmf.circuit-breaker-sync pkgs.jq];
    } ''
      circuit-breaker-sync --validate --inventory ${inventory} --format json | jq -e '.inventory.resources > 10' >/dev/null
      echo "${toString t.count} exporter tests passed; fixture inventory validates" | tee $out
    ''
