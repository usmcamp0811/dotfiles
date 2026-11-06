#!/usr/bin/env bash
# vault-access: derive one least-privilege Vault policy PER SERVICE from what the vault-agent
# templates actually read, and say which hosts need which policy.
#
# Run it from the root of the flake that defines your nixosConfigurations (it evaluates every
# host of that flake):
#
#   vault-access                   write <vault-dir>/policies/svc-*.hcl and
#                                  <vault-dir>/generated/service-policies.nix
#   vault-access --check           regenerate to a temp dir; exit non-zero if the repo differs (CI)
#   vault-access --show vm-media   print the policies one host needs (writes nothing)
#
# A "service" is a key of fmf.services.vault-agent.services (gitea's secrets, pia-vpn, rkvm, ...).
# Its policy grants exactly the secrets its templates read. When the same service name reads
# different secrets on different hosts, each distinct set becomes its own policy, named after the
# secrets (svc-k3s--argocd-repo-k3s), so no host is granted another host's extras.
# The whole fleet is always evaluated (naming depends on every host); hosts are evaluated one
# `nix eval` at a time, a few in parallel, so memory stays small.
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

mount="secret/campground" # the KV v2 mount that vault-agent templates resolve under
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
    --check) mode=check; shift ;;
    --show) mode=show; show_host="${2:?--show needs a host}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

root="$(git rev-parse --show-toplevel)"
flake="${flake:-git+file://$root}"
vault_dir="$root/$vault_rel"
policy_dir="$vault_dir/policies"
mapping_file="$vault_dir/generated/service-policies.nix"
extract="@EXTRACT@"

mapfile -t hosts < <(find "$root/$hosts_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/json" "$work/policies"

extract_host() {
  local h="$1" try
  # nix sometimes fails with "Stale file handle" reading its git cache while other evals run;
  # retry a few times, but a real evaluation error fails the same way every time and still fails.
  for try in 1 2 3; do
    if nix eval --impure --json --expr \
      "(import $extract) { flake = \"$flake\"; host = \"$h\"; }" >"$work/json/$h.json" 2>"$work/json/$h.err"; then
      jq --arg h "$h" '. + {host: $h}' "$work/json/$h.json" >"$work/json/$h.host.json"
      return 0
    fi
    sleep "$try"
  done
  echo "FAIL $h (evaluation, 3 attempts)" >&2
  tail -n 5 "$work/json/$h.err" | sed 's/^/    /' >&2
  : >"$work/json/$h.failed"
}
export -f extract_host
export work flake extract

printf '%s\n' "${hosts[@]}" | xargs -P "$jobs" -I{} bash -c 'extract_host {}'

if [ -n "$(find "$work/json" -name '*.failed' -print -quit)" ]; then
  echo "some hosts failed to evaluate; refusing to write anything." >&2
  exit 1
fi

# All hosts -> { policies: { <name>: <hcl> }, hosts: { <host>: [<policy>...] } }
read -r -d '' JQ <<'JQ' || true
def leaf: .path | split("/") | last;

def rule($m):
  if (.path | test("-pki/|/pki/"))
    then {path: .path, caps: (if (.path | test("/issue/")) then ["update"] else ["read"] end), kind: "pki"}
  elif (.path | startswith($m + "/data/"))
    then {path: .path, caps: ["read"], kind: "kv", logical: ($m + "/" + (.path | ltrimstr($m + "/data/")))}
  elif (.path | startswith($m + "/"))
    then {path: ($m + "/data/" + (.path | ltrimstr($m + "/"))), caps: ["read"], kind: "kv", logical: .path}
  else {path: .path, caps: [], kind: "unresolved"} end;

def stanza($m):
  if .kind == "unresolved" then
    "# UNRESOLVED (not under \($m) and not a PKI path), no access granted: \(.path)\n"
  else
    "path \"\(.path)\" {\n  capabilities = [\(.caps | map("\"" + . + "\"") | join(", "))]\n}\n"
    + (if .kind == "kv" then
        "# KV v2 mount discovery for the agent, no secret data\n"
        + "path \"sys/internal/ui/mounts/\(.logical)\" {\n  capabilities = [\"read\"]\n}\n"
      else "" end)
  end;

# one row per (host, service) that reads at least one secret
[ .[] | select(.enabled) | .host as $h | .services | to_entries[]
  | {svc: .key, host: $h,
     rules: ([.value[] | rule($m)] | group_by(.path) | map(.[0]) | sort_by(.path))}
  | select(.rules | length > 0) ] as $rows

# a unit = a service name + one distinct set of secrets; several sets => name carries the secrets
| ($rows | group_by(.svc) | map(
    group_by([.rules[].path]) as $variants
    | $variants | map({svc: .[0].svc, rules: .[0].rules, hosts: (map(.host) | unique),
                       multi: (($variants | length) > 1)}))
  | flatten
  | map(. + {name: ("svc-" + (.svc | ascii_downcase)
        + (if .multi then "--" + ([.rules[] | leaf] | join("-") | ascii_downcase) else "" end))})) as $units

| ($units | group_by(.name) | map(select(length > 1)) ) as $collisions
| if ($collisions | length) > 0
  then error("policy name collision (names are case-insensitive in Vault): " + ($collisions | map(.[0].name) | join(", ")))
  else
    { policies: ($units | map({key: .name, value:
        ("# GENERATED by `vault-access` from the vault-agent templates of service \"\(.svc)\".\n"
        + "# Do not edit: change the module/host config and regenerate with `vault-access` (fmf package; see docs/VAULT-APPROLES.md).\n"
        + "# Grants exactly the secrets that service reads. KV mount: \($m) (v2).\n\n"
        + (.rules | map(stanza($m)) | join("\n")))}) | from_entries),
      hosts: ($units | map(. as $u | $u.hosts[] | {h: ., n: $u.name}) | group_by(.h)
              | map({key: .[0].h, value: (map(.n) | unique)}) | from_entries) }
  end
JQ

jq -s --arg m "$mount" "$JQ" "$work"/json/*.host.json >"$work/result.json"

# materialise
jq -r '.policies | keys[]' "$work/result.json" | while read -r name; do
  jq -r --arg n "$name" '.policies[$n]' "$work/result.json" >"$work/policies/$name.hcl"
done
mkdir -p "$work/generated"
jq -r '"# GENERATED by `vault-access`; do not edit; regenerate with `vault-access` (fmf package).\n# host -> generated per-service policies its vault-agent services need.\n{\n"
  + (.hosts | to_entries | map("  \"\(.key)\" = [" + (.value | map("\"" + . + "\"") | join(" ")) + "];") | join("\n"))
  + "\n}"' "$work/result.json" >"$work/generated/service-policies.nix"

case "$mode" in
  show)
    names=$(jq -r --arg h "$show_host" '.hosts[$h] // [] | .[]' "$work/result.json")
    [ -n "$names" ] || { echo "# $show_host: no vault-agent templates"; exit 0; }
    for n in $names; do echo "##### $n"; cat "$work/policies/$n.hcl"; done
    ;;
  check)
    rc=0
    for f in "$work"/policies/*.hcl; do
      b=$(basename "$f")
      if [ -f "$policy_dir/$b" ]; then diff -u "$policy_dir/$b" "$f" || rc=1; else echo "missing: $b"; rc=1; fi
    done
    for f in "$policy_dir"/svc-*.hcl "$policy_dir"/host-*.hcl; do
      [ -e "$f" ] || continue
      [ -f "$work/policies/$(basename "$f")" ] || { echo "stale: $(basename "$f")"; rc=1; }
    done
    if [ -f "$mapping_file" ]; then diff -u "$mapping_file" "$work/generated/service-policies.nix" || rc=1
    else echo "missing: $mapping_file"; rc=1; fi
    [ $rc -eq 0 ] && echo "vault-access: up to date"
    exit $rc
    ;;
  write)
    mkdir -p "$vault_dir/generated"
    # drop policies that are no longer generated (this tool owns svc-*; host-* was an earlier layout)
    for f in "$policy_dir"/svc-*.hcl "$policy_dir"/host-*.hcl; do
      [ -e "$f" ] || continue
      [ -f "$work/policies/$(basename "$f")" ] || { rm -f "$f"; echo "removed $(basename "$f")"; }
    done
    for f in "$work"/policies/*.hcl; do cp "$f" "$policy_dir/$(basename "$f")"; done
    cp "$work/generated/service-policies.nix" "$mapping_file"
    echo "wrote $(find "$work/policies" -name "*.hcl" | wc -l) policies and $(basename "$mapping_file") ($(jq '.hosts | length' "$work/result.json") hosts)"
    ;;
esac
