#!/usr/bin/env bash
# vault-access: write (or check) the per-service Vault policies and the host -> policies map that
# lib.fmf.vaultAccess derives from the vault-agent templates of every host in a flake.
#
# Run it from the root of the flake that defines your nixosConfigurations:
#
#   vault-access                   write <vault-dir>/policies/svc-*.hcl and
#                                  <vault-dir>/generated/service-policies.nix
#   vault-access --check           derive again; exit non-zero if the committed files differ (CI)
#   vault-access --show vm-media   print the policies one host needs (writes nothing)
#
# The rules (what a service reads, naming, capabilities) live in lib/vault-access/default.nix and
# are shared with the Nix-side check. This script only evaluates each host (one `nix eval` at a
# time, a few in parallel, so memory stays small) and writes the result.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: vault-access [--check | --show HOST] [options]
  --mount PATH       KV v2 mount that vault-agent templates resolve under   (secret/campground)
  --flake REF        flake to evaluate                                      (git+file://<git root>)
  --hosts-dir DIR    directory with one sub-directory per host, relative to the git root
                                                                            (systems/x86_64-linux)
  --vault-dir DIR    where policies/ and generated/ live, relative to the git root
                                                                            (systems/x86_64-linux/vm-vault/vault)
  --jobs N           hosts evaluated in parallel                            (3)
USAGE
}

mount="secret/campground"
jobs=3
mode="write"
flake=""
show_host=""
hosts_dir="systems/x86_64-linux"
vault_rel="systems/x86_64-linux/vm-vault/vault"

while [ $# -gt 0 ]; do
  case "$1" in
    --mount) mount="$2"; shift 2 ;;
    --flake) flake="$2"; shift 2 ;;
    --hosts-dir) hosts_dir="$2"; shift 2 ;;
    --vault-dir) vault_rel="$2"; shift 2 ;;
    --jobs) jobs="$2"; shift 2 ;;
    --check) mode="check"; shift ;;
    --show) mode="show"; show_host="${2:?--show needs a host}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

root="$(git rev-parse --show-toplevel)"
flake="${flake:-git+file://$root}"
vault_dir="$root/$vault_rel"
policy_dir="$vault_dir/policies"
mapping_file="$vault_dir/generated/service-policies.nix"
lib_file="@LIB@"

mapfile -t hosts < <(find "$root/$hosts_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/json" "$work/out"

extract_host() {
  local h="$1" try
  # nix sometimes fails with "Stale file handle" reading its git cache while other evals run;
  # retry a few times, but a real evaluation error fails the same way every time and still fails.
  for try in 1 2 3; do
    if nix eval --impure --json --expr "
      let c = (builtins.getFlake \"$flake\").nixosConfigurations.\"$h\";
      in (import $lib_file { lib = c.pkgs.lib; }).vaultAccess.extractHost c.config" \
      >"$work/json/$h.json" 2>"$work/json/$h.err"; then
      return 0
    fi
    sleep "$try"
  done
  echo "FAIL $h (evaluation, 3 attempts)" >&2
  tail -n 5 "$work/json/$h.err" | sed 's/^/    /' >&2
  : >"$work/json/$h.failed"
}
export -f extract_host
export work flake lib_file

printf '%s\n' "${hosts[@]}" | xargs -P "$jobs" -I{} bash -c 'extract_host {}'

if [ -n "$(find "$work/json" -name '*.failed' -print -quit)" ]; then
  echo "some hosts failed to evaluate; refusing to write anything." >&2
  exit 1
fi

# {host: extractHost result} for the whole fleet, then the shared derivation.
for h in "${hosts[@]}"; do jq -c --arg h "$h" '{($h): .}' "$work/json/$h.json"; done | jq -s 'add' >"$work/hosts.json"

first="${hosts[0]}"
nix eval --impure --json --expr "
  let
    c = (builtins.getFlake \"$flake\").nixosConfigurations.\"$first\";
    va = (import $lib_file { lib = c.pkgs.lib; }).vaultAccess;
  in va.render { mount = \"$mount\"; hosts = builtins.fromJSON (builtins.readFile $work/hosts.json); }" \
  >"$work/result.json"

jq -r '.policies | keys[]' "$work/result.json" | while read -r name; do
  jq -j --arg n "$name" '.policies[$n]' "$work/result.json" >"$work/out/$name.hcl"
done
mkdir -p "$work/generated"
jq -j '.mapping' "$work/result.json" >"$work/generated/service-policies.nix"

case "$mode" in
  show)
    names=$(jq -r --arg h "$show_host" '.hosts[$h] // [] | .[]' "$work/result.json")
    [ -n "$names" ] || { echo "# $show_host: no vault-agent templates"; exit 0; }
    for n in $names; do echo "##### $n"; cat "$work/out/$n.hcl"; done
    ;;
  check)
    rc=0
    for f in "$work"/out/*.hcl; do
      b=$(basename "$f")
      if [ -f "$policy_dir/$b" ]; then diff -u "$policy_dir/$b" "$f" || rc=1; else echo "missing: $b"; rc=1; fi
    done
    for f in "$policy_dir"/svc-*.hcl "$policy_dir"/host-*.hcl; do
      [ -e "$f" ] || continue
      [ -f "$work/out/$(basename "$f")" ] || { echo "stale: $(basename "$f")"; rc=1; }
    done
    if [ -f "$mapping_file" ]; then diff -u "$mapping_file" "$work/generated/service-policies.nix" || rc=1
    else echo "missing: $mapping_file"; rc=1; fi
    [ $rc -eq 0 ] && echo "vault-access: up to date"
    exit $rc
    ;;
  write)
    mkdir -p "$vault_dir/generated" "$policy_dir"
    # drop policies that are no longer generated (this tool owns svc-*; host-* was an earlier layout)
    for f in "$policy_dir"/svc-*.hcl "$policy_dir"/host-*.hcl; do
      [ -e "$f" ] || continue
      [ -f "$work/out/$(basename "$f")" ] || { rm -f "$f"; echo "removed $(basename "$f")"; }
    done
    for f in "$work"/out/*.hcl; do cp "$f" "$policy_dir/$(basename "$f")"; done
    cp "$work/generated/service-policies.nix" "$mapping_file"
    echo "wrote $(find "$work/out" -name '*.hcl' | wc -l) policies and $(basename "$mapping_file") ($(jq '.hosts | length' "$work/result.json") hosts)"
    ;;
esac
