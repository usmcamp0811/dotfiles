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
#   vault-access --audit           compare live Vault (roles, policies, content) with the repo
#
# The rules (what a service reads, naming, capabilities) live in lib/vault-access/default.nix and
# are shared with the Nix-side check. This script only evaluates each host (one `nix eval` at a
# time, a few in parallel, so memory stays small) and writes the result.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: vault-access [--check | --show HOST | --audit] [options]
  --mount PATH       KV v2 mount that vault-agent templates resolve under   (secret/campground)
  --flake REF        flake to evaluate                                      (git+file://<git root>)
  --hosts-dir DIR    directory with one sub-directory per host, relative to the git root
                                                                            (systems/x86_64-linux)
  --vault-dir DIR    where policies/ and generated/ live, relative to the git root
                                                                            (systems/x86_64-linux/vm-vault/vault)
  --jobs N           hosts evaluated in parallel                            (3)
  --audit            compare LIVE Vault with the repo (read-only; needs vault CLI, VAULT_ADDR, a token)
  --brief            with --audit: hide the roles that are fine, show only what needs attention
USAGE
}

mount="secret/campground"
jobs=3
mode="write"
flake=""
show_host=""
brief=0
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
    --audit) mode="audit"; shift ;;
    --brief) brief=1; shift ;;
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

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ---- --audit: compare LIVE Vault with what the repo declares -----------------------------------
# Read-only. Needs the `vault` CLI, VAULT_ADDR and a token that can read auth/approle/role/* and
# sys/policies/acl/* (the admin policy does). Prints a scoreboard and a per-role table; exits 1 when
# it finds drift (missing/unmanaged/drifted roles or policies, dangling references), so it can run
# from cron. Colour only on a terminal (and never with NO_COLOR set).
audit() {
  command -v vault >/dev/null 2>&1 || { echo "audit needs the vault CLI on PATH" >&2; exit 2; }
  [ -n "${VAULT_ADDR:-}" ] || { echo "set VAULT_ADDR (e.g. https://vault.lan.aicampground.com)" >&2; exit 2; }
  vault token lookup >/dev/null 2>&1 || { echo "no valid Vault token: vault login, or set VAULT_TOKEN" >&2; exit 2; }
  local a="$work/audit" r p pol n
  mkdir -p "$a"

  # ---- gather ----
  # declared: roles from approles.nix (evaluated, so the generated attachments are included)
  nix-instantiate --eval --strict --json "$vault_dir/approles.nix" >"$a/declared.json"

  # live roles with their policies and how many secret-ids exist (0 = nothing can log in yet)
  vault list -format=json auth/approle/role | jq -r '.[]' >"$a/roles.txt"
  : >"$a/live.jsonl"
  while read -r r; do
    pol=$(vault read -format=json "auth/approle/role/$r" | jq -c '.data.token_policies // []')
    n=$(vault list -format=json "auth/approle/role/$r/secret-id" 2>/dev/null | jq 'length' 2>/dev/null || true)
    jq -nc --arg r "$r" --argjson p "$pol" --argjson n "${n:-0}" '{($r): {policies: $p, secret_ids: $n}}' >>"$a/live.jsonl"
  done <"$a/roles.txt"
  jq -s 'add // {}' "$a/live.jsonl" >"$a/live.json"

  # policies: files in the repo vs Vault, including content
  vault policy list -format=json | jq -r '.[]' | sort >"$a/live-policies.txt"
  find "$policy_dir" -maxdepth 1 -name '*.hcl' -printf '%f\n' | sed 's/\.hcl$//' | sort >"$a/decl-policies.txt"
  comm -23 "$a/decl-policies.txt" "$a/live-policies.txt" >"$a/pol-missing.txt"
  comm -13 "$a/decl-policies.txt" "$a/live-policies.txt" | grep -Ev '^(default|root|default-ceiling)$' >"$a/pol-extra.txt" || true
  : >"$a/pol-drift.txt"
  while read -r p; do
    # the vault module stores the `vault policy fmt`-ed file, so compare against that
    cp "$policy_dir/$p.hcl" "$a/fmt.hcl"; vault policy fmt "$a/fmt.hcl" >/dev/null 2>&1 || true
    [ "$(vault policy read "$p" 2>/dev/null)" = "$(cat "$a/fmt.hcl")" ] || echo "$p" >>"$a/pol-drift.txt"
  done < <(comm -12 "$a/decl-policies.txt" "$a/live-policies.txt")

  # ---- one row per role (declared or live), then the numbers ----
  jq -n --slurpfile d "$a/declared.json" --slurpfile l "$a/live.json" --rawfile pols "$a/live-policies.txt" '
    def lst: if length == 0 then "-" else join(",") end;
    ($d[0] | with_entries(.value |= (.token_policies // []))) as $dec
    | $l[0] as $live
    | ($pols | split("\n") | map(select(. != ""))) as $exist
    | [ ($dec | keys[]), ($live | keys[]) ] | unique
    | map(. as $r
        | ($dec[$r]) as $want | ($live[$r]) as $got
        | ($got.policies // $want) as $pols_
        | ([$pols_[] | select(. as $p | ($exist | index($p)) == null)]) as $dangling
        | { role: $r, n: ($pols_ | length), svc: ([$pols_[] | select(startswith("svc-"))] | length),
            campground: ($pols_ | index("campground") != null), admin: ($pols_ | index("admin") != null),
            sids: ($got.secret_ids // null),
            state: (if $got == null then "missing"
                    elif $want == null then "unmanaged"
                    elif ($want | sort) != ($got.policies | sort) then "drift"
                    elif ($dangling | length) > 0 then "dangling"
                    elif $got.secret_ids == 0 then "inert"
                    else "ok" end),
            detail: (if $got != null and $want != null and ($want | sort) != ($got.policies | sort)
                     then "add \((($want - $got.policies) | lst))  remove \((($got.policies - $want) | lst))"
                     else ($dangling | lst) end) })
    | map(. + { note:
        (if .state == "missing" then "declared in approles.nix, not in Vault"
         elif .state == "unmanaged" then "in Vault, not declared (created by hand?)"
         elif .state == "drift" then .detail
         elif .state == "dangling" then "points at a policy that does not exist: \(.detail)"
         elif .state == "inert" then "no secret-id issued yet: nothing can log in with it"
         elif .admin then "admin: the policy agent / legacy"
         elif .campground and .svc > 0 then "has its svc policies: can drop campground"
         elif .campground then "legacy name: no host mapping, still broad"
         else "" end) })
    | sort_by([({"missing":0,"unmanaged":1,"drift":2,"dangling":3,"inert":4,"ok":5}[.state]), .role])' >"$a/rows.json"

  # ---- render ----
  local red="" yel="" grn="" dim="" bold="" rst=""
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    red=$'\e[31m'; yel=$'\e[33m'; grn=$'\e[32m'; dim=$'\e[2m'; bold=$'\e[1m'; rst=$'\e[0m'
  fi
  count() { jq -r --arg s "$1" '[.[] | select(.state == $s)] | length' "$a/rows.json"; }
  local n_total n_missing n_unman n_drift n_dang n_inert n_ok
  n_total=$(jq 'length' "$a/rows.json"); n_missing=$(count missing); n_unman=$(count unmanaged)
  n_drift=$(count drift); n_dang=$(count dangling); n_inert=$(count inert); n_ok=$(count ok)
  local p_decl p_miss p_extra p_drift
  p_decl=$(wc -l <"$a/decl-policies.txt"); p_miss=$(wc -l <"$a/pol-missing.txt")
  p_extra=$(wc -l <"$a/pol-extra.txt"); p_drift=$(wc -l <"$a/pol-drift.txt")
  # least privilege: of the roles that are not admin by design, how many no longer carry campground
  local lp_den lp_num lp_ready lp_bar
  lp_den=$(jq '[.[] | select(.state != "missing" and (.admin | not))] | length' "$a/rows.json")
  lp_num=$(jq '[.[] | select(.state != "missing" and (.admin | not) and (.campground | not))] | length' "$a/rows.json")
  lp_ready=$(jq '[.[] | select(.campground and .svc > 0 and (.admin | not) and .state != "missing")] | length' "$a/rows.json")
  lp_bar=$(awk -v n="$lp_num" -v d="$lp_den" 'BEGIN { w = 24; f = (d > 0) ? int(w * n / d + 0.5) : 0; s = ""; for (i = 0; i < w; i++) s = s (i < f ? "█" : "░"); print s }')

  local findings=$((n_missing + n_unman + n_drift + n_dang + p_miss + p_extra + p_drift))
  mark() { [ "$1" -eq 0 ] && echo "${grn}✔${rst}" || echo "${red}✖${rst}"; }

  echo
  printf ' %sVault audit%s  %s%s · %s%s\n' "$bold" "$rst" "$dim" "$VAULT_ADDR" "$(date '+%Y-%m-%d %H:%M')" "$rst"
  printf ' %s%s%s\n' "$dim" "────────────────────────────────────────────────────────────────────────────────────────" "$rst"
  printf ' %sSCOREBOARD%s\n' "$bold" "$rst"
  printf '  %s  %-16s %s roles · %s ok · %s missing · %s unmanaged · %s drifted · %s dangling\n' \
    "$(mark $((n_missing + n_unman + n_drift + n_dang)))" "Roles" "$n_total" "$n_ok" "$n_missing" "$n_unman" "$n_drift" "$n_dang"
  printf '  %s  %-16s %s in repo · %s missing in Vault · %s extra in Vault · %s content drift\n' \
    "$(mark $((p_miss + p_extra + p_drift)))" "Policies" "$p_decl" "$p_miss" "$p_extra" "$p_drift"
  if [ "$n_inert" -eq 0 ]; then printf '  %s✔%s  %-16s every role has a secret-id issued\n' "$grn" "$rst" "Credentials"
  else printf '  %s●%s  %-16s %s role(s) have no secret-id yet (inert until you issue one)\n' "$yel" "$rst" "Credentials" "$n_inert"; fi
  lp_col=$yel; [ "$lp_num" -eq "$lp_den" ] && lp_col=$grn
  printf '  %s◐%s  %-16s %s%s%s  %s of %s roles are off campground\n' "$lp_col" "$rst" "Least privilege" "$grn" "$lp_bar" "$rst" "$lp_num" "$lp_den"
  [ "$lp_ready" -gt 0 ] && printf '     %s%s role(s) already carry their svc-* policies and can drop campground%s\n' "$dim" "$lp_ready" "$rst"

  echo
  printf ' %sROLES%s %s(problems first)%s\n' "$bold" "$rst" "$dim" "$rst"
  printf ' %s%-12s %-28s %8s %5s  %-10s %s%s\n' "$dim" "STATE" "ROLE" "POLICIES" "SVC" "BROAD" "NOTE" "$rst"
  jq -r --argjson brief "$brief" '.[] | select($brief == 0 or .state != "ok") | [ .state, .role, (.n | tostring), (.svc | tostring),
                 ((if .campground then "campground" elif .admin then "admin" else "-" end)),
                 (if .sids == null then "-" else (.sids | tostring) end), .note ] | @tsv' "$a/rows.json" |
    while IFS=$'\t' read -r st role npol nsvc broad _sids note; do
      case "$st" in
        missing | unmanaged) col=$red; icon="✖" ;;
        drift | dangling) col=$red; icon="≠" ;;
        inert) col=$yel; icon="●" ;;
        *) col=""; icon="✔" ;;
      esac
      [ "$st" = ok ] && icon="${grn}✔${rst}" || icon="${col}${icon}${rst}"
      printf ' %s %-10s %-28s %8s %5s  %-10s %s\n' "$icon" "$st" "$role" "$npol" "$nsvc" "$broad" "$note"
    done

  if [ $((p_miss + p_extra + p_drift)) -gt 0 ] || [ "$n_dang" -gt 0 ]; then
    echo; printf ' %sPOLICY FINDINGS%s\n' "$bold" "$rst"
    sed "s/^/  ${red}missing in Vault${rst}   /" "$a/pol-missing.txt"
    sed "s/^/  ${red}extra in Vault${rst}     /" "$a/pol-extra.txt"
    sed "s/^/  ${red}content differs${rst}    /" "$a/pol-drift.txt"
  fi

  echo; printf ' %s%s finding(s)%s' "$bold" "$findings" "$rst"
  if [ "$findings" -eq 0 ]; then printf '  %sVault matches the repo%s\n\n' "$grn" "$rst"; else printf '  %s(exit 1)%s\n\n' "$dim" "$rst"; fi
  [ "$findings" -eq 0 ]
}

if [ "$mode" = "audit" ]; then audit; exit $?; fi

mapfile -t hosts < <(find "$root/$hosts_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

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
