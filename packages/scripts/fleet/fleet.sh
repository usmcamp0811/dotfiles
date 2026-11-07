#!/usr/bin/env bash
# fleet: derive the network files of a flake from the `fmf.host` records of its hosts, and write
# (or check) them. Run it from the root of the flake that defines your nixosConfigurations:
#
#   fleet                   write <out>/leases.nix, dns.nix and forwards.nix
#   fleet --check           derive again; exit non-zero if the committed files differ (CI)
#   fleet --show HOST       print what is derived for one host (writes nothing)
#
# What is derived, and why, is in fmf's docs/HOST-MODEL.md. The rules live in lib/fleet/default.nix
# (shared with the Nix-side drift check); this script only evaluates each host (one `nix eval` at a
# time, a few in parallel, so memory stays small) and writes the result. It refuses to write anything
# while the fleet has errors (duplicate address or MAC, a reference to a retired host, ...).
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: fleet [--check | --show HOST] [options]
  --flake REF          flake to evaluate                                   (git+file://<git root>)
  --hosts-dir DIR      directory with one sub-directory per host, relative to the git root
                                                                           (systems/x86_64-linux)
  --out DIR            where the generated files go, relative to the git root
                                                                           (network/generated)
  --device-leases GLOB lease files of machines that are not hosts (iot, wifi, appliances), relative
                       to the git root; the zone is the file name up to `-leases.nix`
                                                                           (systems/x86_64-linux/blue-ridge/router/*-leases.nix)
  --jobs N             hosts evaluated in parallel                         (2)
USAGE
}

jobs=2
mode="write"
flake=""
show_host=""
hosts_dir="systems/x86_64-linux"
out_rel="network/generated"
devices_glob="systems/x86_64-linux/blue-ridge/router/*-leases.nix"

while [ $# -gt 0 ]; do
  case "$1" in
    --flake) flake="$2"; shift 2 ;;
    --hosts-dir) hosts_dir="$2"; shift 2 ;;
    --out) out_rel="$2"; shift 2 ;;
    --device-leases) devices_glob="$2"; shift 2 ;;
    --jobs) jobs="$2"; shift 2 ;;
    --check) mode="check"; shift ;;
    --show) mode="show"; show_host="${2:?--show needs a host}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

root="$(git rev-parse --show-toplevel)"
flake="${flake:-git+file://$root}"
out_dir="$root/$out_rel"
lib_file="@LIB@"

mapfile -t hosts < <(find "$root/$hosts_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/json"

extract_host() {
  local h="$1" try
  # nix sometimes fails with "Stale file handle" reading its git cache while other evals run;
  # retry, but a real evaluation error fails the same way every time and still fails.
  for try in 1 2 3; do
    if nix eval --impure --json --expr "
      let c = (builtins.getFlake \"$flake\").nixosConfigurations.\"$h\";
      in {
        record = (import $lib_file { lib = c.pkgs.lib; }).fleet.extract \"$h\" c.config;
        zones = c.config.fmf.network.zones or {};
      }" >"$work/json/$h.json" 2>"$work/json/$h.err"; then
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
  echo "some hosts failed to evaluate; refusing to continue." >&2
  exit 1
fi

# { host: record } for the fleet; the zone catalogue is the same on every host, take the first
for h in "${hosts[@]}"; do jq -c --arg h "$h" '{($h): .record}' "$work/json/$h.json"; done | jq -s 'add' >"$work/hosts.json"
jq -c '.zones' "$work/json/${hosts[0]}.json" >"$work/zones.json"

# Device leases: machines that are not hosts keep their own lease files. The zone is the file name.
dev_expr="[]"
mapfile -t dev_files < <(find "$root/$(dirname "$devices_glob")" -maxdepth 1 -name "$(basename "$devices_glob")" 2>/dev/null | sort)
for f in "${dev_files[@]}"; do
  zone="$(basename "$f")"; zone="${zone%-leases.nix}"
  dev_expr="$dev_expr ++ (map (l: l // {zone = \"$zone\";}) (import $f))"
done

first="${hosts[0]}"
nix eval --impure --json --expr "
  let
    c = (builtins.getFlake \"$flake\").nixosConfigurations.\"$first\";
    fl = (import $lib_file { lib = c.pkgs.lib; }).fleet;
    r = fl.mk {
      hosts = builtins.fromJSON (builtins.readFile $work/hosts.json);
      zones = builtins.fromJSON (builtins.readFile $work/zones.json);
      deviceLeases = $dev_expr;
    };
  in {
    files = fl.render r;
    inherit (r) hosts errors warnings leases dns forwards;
  }" >"$work/result.json"

nerr="$(jq '.errors | length' "$work/result.json")"
jq -r '.warnings[] | "warning: \(.host): \(.message)"' "$work/result.json" >&2
if [ "$nerr" -ne 0 ]; then
  jq -r '.errors[] | "error: \(.host): \(.message)"' "$work/result.json" >&2
  echo "the fleet has $nerr error(s); nothing was written." >&2
  exit 1
fi

for n in leases dns forwards; do jq -j --arg n "$n" '.files[$n]' "$work/result.json" >"$work/$n.nix"; done

case "$mode" in
  show)
    jq -r --arg h "$show_host" '
      "# \($h): lifecycle " + (if (.hosts.active | index($h)) then "active" elif (.hosts.standby | index($h)) then "standby" elif (.hosts.retired | index($h)) then "retired" else "not managed" end),
      "leases:",
      (.leases | to_entries[] | .key as $z | .value[] | select(.hostname | ascii_downcase | . == ($h | sub("^vm-"; "")) or startswith(($h | sub("^vm-"; "")) + "-")) | "  \($z)\t\(.mac)\t\(.ip)\t\(.hostname)"),
      "dns:",
      (.dns | to_entries[] | select(.key == $h or .key == ($h | sub("^vm-"; "")) or (.key | startswith($h + ".")) or (.key | startswith(($h | sub("^vm-"; "")) + "."))) | "  \(.key)\t\(.value)")' "$work/result.json"
    ;;
  check)
    rc=0
    for n in leases dns forwards; do
      if [ -f "$out_dir/$n.nix" ]; then diff -u "$out_dir/$n.nix" "$work/$n.nix" || rc=1
      else echo "missing: $out_rel/$n.nix"; rc=1; fi
    done
    [ $rc -eq 0 ] && echo "fleet: up to date"
    exit $rc
    ;;
  write)
    mkdir -p "$out_dir"
    for n in leases dns forwards; do cp "$work/$n.nix" "$out_dir/$n.nix"; done
    echo "wrote $out_rel/: $(jq '[.leases[][]] | length' "$work/result.json") host leases, $(jq '.dns | length' "$work/result.json") DNS names, $(jq '.forwards | length' "$work/result.json") port forwards ($(jq '.hosts.active | length' "$work/result.json") active hosts, $(jq '.hosts.standby | length' "$work/result.json") standby, $(jq '.hosts.retired | length' "$work/result.json") retired)"
    ;;
esac
