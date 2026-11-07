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
#   vault-access --audit           compare live Vault (roles, policies, content, IP binding) with the repo
#   vault-access --audit --audit-log FILE   also reconcile the source addresses the Vault audit log saw
#   vault-access --fix [--apply]   bring live Vault in line with the repo (dry run unless --apply)
#
# The rules (what a service reads, naming, capabilities) live in lib/vault-access/default.nix and
# are shared with the Nix-side check. This script only evaluates each host (one `nix eval` at a
# time, a few in parallel, so memory stays small) and writes the result.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: vault-access [--check | --show HOST | --audit | --fix [--apply]] [options]
  --mount PATH       KV v2 mount that vault-agent templates resolve under   (secret/campground)
  --flake REF        flake to evaluate                                      (git+file://<git root>)
  --hosts-dir DIR    directory with one sub-directory per host, relative to the git root
                                                                            (systems/x86_64-linux)
  --vault-dir DIR    where policies/ and generated/ live, relative to the git root
                                                                            (systems/x86_64-linux/vm-vault/vault)
  --jobs N           hosts evaluated in parallel                            (3)
  --audit            compare LIVE Vault with the repo (read-only; needs vault CLI, VAULT_ADDR, a token)
  --brief            with --audit: hide the roles that are fine, show only what needs attention
  --audit-log FILE   with --audit: reconcile the audit log (FILE, or - for stdin) against each role's expected
                     source address; a log tail is enough (tail -n 300000 vault_audit.log)
  --since TIME       with --audit-log: only events after TIME (ISO 8601 UTC, e.g. 2026-11-07T04:00:00Z)
  --proxy IPS        with --audit-log: comma list of reverse-proxy addresses (default: the expected
                     address of vm-lan-traefik / lan-traefik)
  --generated-leases FILE
                     leases generated from host records by `fleet` (zone -> list), merged with the
                     lease files above when the file exists          (network/generated/leases.nix)
  --leases GLOB      static DHCP lease files, relative to the git root, used to derive expected
                     addresses; `none` skips them          (systems/x86_64-linux/blue-ridge/router/*-leases.nix)
  --fix              converge live Vault to the repo (policies, then roles). Dry run unless --apply; never deletes
USAGE
}

mount="secret/campground"
jobs=3
mode="write"
flake=""
show_host=""
brief=0
apply=0
audit_log=""
since=""
proxy_arg=""
leases_glob="systems/x86_64-linux/blue-ridge/router/*-leases.nix"
generated_leases="network/generated/leases.nix"
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
    --audit-log) mode="audit"; audit_log="${2:?--audit-log needs a file (or - for stdin)}"; shift 2 ;;
    --since) since="${2:?--since needs a time}"; shift 2 ;;
    --proxy) proxy_arg="${2:?--proxy needs an address list}"; shift 2 ;;
    --leases) leases_glob="${2:?--leases needs a glob}"; shift 2 ;;
    --generated-leases) generated_leases="${2:?--generated-leases needs a file}"; shift 2 ;;
    --fix) mode="fix"; shift ;;
    --apply) apply=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ "$apply" -eq 0 ] || [ "$mode" = "fix" ] || { echo "--apply only works with --fix" >&2; exit 2; }
root="$(git rev-parse --show-toplevel)"
flake="${flake:-git+file://$root}"
vault_dir="$root/$vault_rel"
policy_dir="$vault_dir/policies"
mapping_file="$vault_dir/generated/service-policies.nix"
ips_file="$vault_dir/generated/host-ips.nix"
expected_extra="$vault_dir/expected-ips.nix"
lib_file="@LIB@"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ---- --audit: compare LIVE Vault with what the repo declares -----------------------------------
# Read-only. Needs the `vault` CLI, VAULT_ADDR and a token that can read auth/approle/role/* and
# sys/policies/acl/* (the admin policy does). Prints a scoreboard and a per-role table; exits 1 when
# it finds drift (missing/unmanaged/drifted roles or policies, dangling references), so it can run
# from cron. Colour only on a terminal (and never with NO_COLOR set).
a="$work/audit"
mkdir -p "$a"

# Read live Vault + the declaration into $a/*. Shared by --audit and --fix.
gather_live() {
  command -v vault >/dev/null 2>&1 || { echo "this needs the vault CLI on PATH" >&2; exit 2; }
  [ -n "${VAULT_ADDR:-}" ] || { echo "set VAULT_ADDR (e.g. https://vault.lan.aicampground.com)" >&2; exit 2; }
  vault token lookup >/dev/null 2>&1 || { echo "no valid Vault token: vault login, or set VAULT_TOKEN" >&2; exit 2; }
  local r p pol n rj cidrs
  # ---- gather ----
  # declared: roles from approles.nix (evaluated, so the generated attachments are included)
  nix-instantiate --eval --strict --json "$vault_dir/approles.nix" >"$a/declared.json"

  # expected source addresses per role name: the generated map (leases) with the hand-kept overrides
  # merged in. Both are optional; a role with no entry simply has no expected address.
  echo '{}' >"$a/exp-generated.json"; have_ips=0
  if [ -f "$ips_file" ]; then nix-instantiate --eval --strict --json "$ips_file" >"$a/exp-generated.json"; have_ips=1; fi
  echo '{}' >"$a/exp-extra.json"
  if [ -f "$expected_extra" ]; then nix-instantiate --eval --strict --json "$expected_extra" >"$a/exp-extra.json"; fi
  jq -s '.[0] as $g | reduce (.[1] | to_entries[]) as $e ($g; .[$e.key] = (((.[$e.key] // []) + $e.value) | unique | sort))' \
    "$a/exp-generated.json" "$a/exp-extra.json" >"$a/expected.json"

  # live roles with their policies, bound CIDRs, and how many secret-ids exist (0 = nothing can log in yet)
  vault list -format=json auth/approle/role | jq -r '.[]' >"$a/roles.txt"
  : >"$a/live.jsonl"
  while read -r r; do
    rj=$(vault read -format=json "auth/approle/role/$r")
    pol=$(jq -c '.data.token_policies // []' <<<"$rj")
    # token_bound_cidrs and secret_id_bound_cidrs together; a lone host may come back as a.b.c.d or a.b.c.d/32
    cidrs=$(jq -c '[(.data.token_bound_cidrs // [])[], (.data.secret_id_bound_cidrs // [])[]] | map(sub("/32$"; "")) | unique' <<<"$rj")
    n=$(vault list -format=json "auth/approle/role/$r/secret-id" 2>/dev/null | jq 'length' 2>/dev/null || true)
    jq -nc --arg r "$r" --argjson p "$pol" --argjson n "${n:-0}" --argjson c "$cidrs" \
      '{($r): {policies: $p, secret_ids: $n, cidrs: $c}}' >>"$a/live.jsonl"
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
}

# one row per role (declared or live): state, policies, notes
build_rows() {
  # ---- one row per role (declared or live), then the numbers ----
  jq -n --slurpfile d "$a/declared.json" --slurpfile l "$a/live.json" --slurpfile x "$a/expected.json" --rawfile pols "$a/live-policies.txt" '
    def lst: if length == 0 then "-" elif length > 3 then (.[0:3] | join(",")) + " +\(length - 3) more" else join(",") end;
    ($d[0] | with_entries(.value |= (.token_policies // []))) as $dec
    | $l[0] as $live
    | ($pols | split("\n") | map(select(. != ""))) as $exist
    | [ ($dec | keys[]), ($live | keys[]) ] | unique
    | map(. as $r
        | ($dec[$r]) as $want | ($live[$r]) as $got
        | ($x[0][$r] // []) as $exp | ($got.cidrs // []) as $cidrs
        | ($got.policies // $want) as $pols_
        | ([$pols_[] | select(. as $p | ($exist | index($p)) == null)]) as $dangling
        | { role: $r, n: ($pols_ | length), svc: ([$pols_[] | select(startswith("svc-"))] | length),
            campground: ($pols_ | index("campground") != null), admin: ($pols_ | index("admin") != null),
            sids: ($got.secret_ids // null),
            exp: $exp, cidrs: $cidrs,
            ipshow: ($exp | if length == 0 then "-" elif length == 1 then .[0] else .[0] + " +\(length - 1)" end),
            bound: (if ($cidrs | length) == 0 then (if ($exp | length) == 0 then "n/a" else "unbound" end)
                    elif (($cidrs | sort) == ($exp | sort)) then "bound"
                    else "mismatch" end),
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
         elif .state == "inert" then "role exists; no secret-id issued yet, so nothing logs in with it"
         elif .admin then "admin: the policy agent / legacy"
         elif .campground and .svc > 0 then "has its svc policies: can drop campground"
         elif .campground then "legacy name: no host mapping, still broad"
         else "" end) })
    | sort_by([({"missing":0,"unmanaged":1,"drift":2,"dangling":3,"inert":4,"ok":5}[.state]), .role])' >"$a/rows.json"
}

# Reconcile the Vault audit log with the expected source addresses: one row per (role, address seen).
#   ok           the address is one the role's host is expected to use
#   proxy        it is the reverse proxy's address: Vault is not seeing the real client
#   other-host   it belongs to a DIFFERENT identity in the lease table (a credential used from another host)
#   no-expected  nothing is known about where this role should connect from
#   unleased     the role has expected addresses, but this one is in no lease (dynamic / unpinned)
classify_log() {
  local src="$audit_log" proxies
  if [ "$src" = "-" ]; then cat >"$a/audit.log"; src="$a/audit.log"; fi
  [ -r "$src" ] || { echo "cannot read audit log: $src" >&2; exit 2; }
  # the role name is plain text on every authenticated event; -R/fromjson? skips torn lines at a tail's edges
  jq -R -r --arg since "$since" 'fromjson?
    | select(.type == "response" and (.auth.metadata.role_name // null) != null
             and (.request.remote_address // null) != null and ($since == "" or .time > $since))
    | [.auth.metadata.role_name, .request.remote_address] | @tsv' "$src" |
    sort | uniq -c | awk '{ print $2 "\t" $3 "\t" $1 }' >"$a/observed.tsv"

  if [ -n "$proxy_arg" ]; then proxies=$(jq -Rc 'split(",")' <<<"$proxy_arg")
  else proxies=$(jq -c '(.["vm-lan-traefik"] // .["lan-traefik"] // [])' "$a/expected.json"); fi

  jq -n --slurpfile e "$a/expected.json" --rawfile obs "$a/observed.tsv" --argjson proxies "$proxies" '
    ($e[0]) as $exp
    | ($exp | to_entries | map(.key as $n | .value[] | {ip: ., n: $n}) | group_by(.ip)
       | map({key: .[0].ip, value: (map(.n) | unique)}) | from_entries) as $owners
    | ($obs | split("\n") | map(select(. != "") | split("\t") | {role: .[0], ip: .[1], n: (.[2] | tonumber)}))
    | map(. as $o | ($exp[$o.role] // []) as $want | ($owners[$o.ip] // []) as $own
        | . + { want: $want, own: $own,
                state: (if ($want | index($o.ip)) != null then "ok"
                        elif ($proxies | index($o.ip)) != null then "proxy"
                        elif ($own | length) > 0 then "other-host"
                        elif ($want | length) == 0 then "no-expected"
                        else "unleased" end) })
    | map(. + { note:
        (if .state == "ok" then ""
         elif .state == "proxy" then "arrives as the reverse proxy: Vault is not seeing the real client (is trusted-proxies deployed?)"
         elif .state == "other-host" then "address belongs to \(.own | join(", ")); expected \(if (.want | length) == 0 then "none known" else (.want | join(",")) end)"
         elif .state == "no-expected" then "no expected address for this role (no lease for its MAC; add it to expected-ips.nix)"
         else "address is in no lease (dynamic or unpinned); expected \(.want | join(","))" end) })
    | sort_by([({"other-host": 0, "proxy": 1, "unleased": 2, "no-expected": 3, "ok": 4}[.state]), .role, .ip])' >"$a/sources.json"
}

audit() {
  gather_live
  build_rows
  if [ -n "$audit_log" ]; then classify_log; fi


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

  # IP binding: of the roles whose host has an expected address, how many are bound to exactly it
  local ip_bound ip_unbound ip_mismatch ip_na ip_den
  ip_bound=$(jq '[.[] | select(.state != "missing" and .bound == "bound")] | length' "$a/rows.json")
  ip_unbound=$(jq '[.[] | select(.state != "missing" and .bound == "unbound")] | length' "$a/rows.json")
  ip_mismatch=$(jq '[.[] | select(.state != "missing" and .bound == "mismatch")] | length' "$a/rows.json")
  ip_na=$(jq '[.[] | select(.state != "missing" and .bound == "n/a")] | length' "$a/rows.json")
  ip_den=$((ip_bound + ip_unbound + ip_mismatch))

  # source addresses seen in the audit log (only with --audit-log)
  local s_total=0 s_events=0 s_ok=0 s_other=0 s_proxy=0 s_unleased=0 s_noexp=0
  if [ -n "$audit_log" ]; then
    scount() { jq -r --arg s "$1" '[.[] | select(.state == $s)] | length' "$a/sources.json"; }
    s_total=$(jq 'length' "$a/sources.json"); s_events=$(jq '[.[].n] | add // 0' "$a/sources.json")
    s_ok=$(scount ok); s_other=$(scount other-host); s_proxy=$(scount proxy)
    s_unleased=$(scount unleased); s_noexp=$(scount no-expected)
  fi

  local findings=$((n_missing + n_unman + n_drift + n_dang + p_miss + p_extra + p_drift + s_other + s_proxy + ip_mismatch))
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
  else printf '  %s●%s  %-16s %s role(s) exist but have no secret-id yet (nothing logs in with them)\n' "$yel" "$rst" "Credentials" "$n_inert"; fi
  lp_col=$yel; [ "$lp_num" -eq "$lp_den" ] && lp_col=$grn
  printf '  %s◐%s  %-16s %s%s%s  %s of %s roles are off campground\n' "$lp_col" "$rst" "Least privilege" "$grn" "$lp_bar" "$rst" "$lp_num" "$lp_den"
  [ "$lp_ready" -gt 0 ] && printf '     %s%s role(s) already carry their svc-* policies and can drop campground%s\n' "$dim" "$lp_ready" "$rst"
  local ip_col=$yel; [ "$ip_den" -gt 0 ] && [ "$ip_bound" -eq "$ip_den" ] && ip_col=$grn; [ "$ip_mismatch" -gt 0 ] && ip_col=$red
  printf '  %s◐%s  %-16s %s of %s roles bound to their expected address  %s(%s unbound · %s mismatch · %s have no expected address)%s\n' \
    "$ip_col" "$rst" "IP binding" "$ip_bound" "$ip_den" "$dim" "$ip_unbound" "$ip_mismatch" "$ip_na" "$rst"
  if [ -n "$audit_log" ]; then
    printf '  %s  %-16s %s role/address pairs in %s events · %s ok · %s other-host · %s via proxy · %s unleased · %s no expected%s\n' \
      "$(mark $((s_other + s_proxy)))" "Sources" "$s_total" "$s_events" "$s_ok" "$s_other" "$s_proxy" "$s_unleased" "$s_noexp" \
      "${since:+ (since $since)}"
  fi
  [ "$have_ips" -eq 0 ] && printf '     %sno %s: run vault-access to derive expected addresses from the leases%s\n' "$dim" "${ips_file#"$root"/}" "$rst"

  echo
  printf ' %sROLES%s %s(problems first)%s\n' "$bold" "$rst" "$dim" "$rst"
  printf ' %s%-12s %-28s %8s %5s  %-10s %-16s %-9s %s%s\n' "$dim" "STATE" "ROLE" "POLICIES" "SVC" "BROAD" "EXPECTED-IP" "IP-BOUND" "NOTE" "$rst"
  jq -r --argjson brief "$brief" '.[] | select($brief == 0 or .state != "ok") | [ .state, .role, (.n | tostring), (.svc | tostring),
                 ((if .campground then "campground" elif .admin then "admin" else "-" end)),
                 .ipshow, .bound, .note ] | @tsv' "$a/rows.json" |
    while IFS=$'\t' read -r st role npol nsvc broad ipshow bound note; do
      case "$st" in
        missing | unmanaged) col=$red; icon="✖" ;;
        drift | dangling) col=$red; icon="≠" ;;
        inert) col=$yel; icon="●" ;;
        *) col=""; icon="✔" ;;
      esac
      [ "$st" = ok ] && icon="${grn}✔${rst}" || icon="${col}${icon}${rst}"
      printf ' %s %-10s %-28s %8s %5s  %-10s %-16s %-9s %s\n' "$icon" "$st" "$role" "$npol" "$nsvc" "$broad" "$ipshow" "$bound" "$note"
    done

  if [ -n "$audit_log" ]; then
    echo
    printf ' %sSOURCE ADDRESSES%s %s(from the Vault audit log; problems first)%s\n' "$bold" "$rst" "$dim" "$rst"
    printf ' %s%-13s %-28s %-16s %7s  %s%s\n' "$dim" "STATE" "ROLE" "SEEN-FROM" "EVENTS" "NOTE" "$rst"
    jq -r --argjson brief "$brief" '.[] | select($brief == 0 or .state != "ok")
        | [ .state, .role, .ip, (.n | tostring), .note ] | @tsv' "$a/sources.json" |
      while IFS=$'\t' read -r st role ip n note; do
        case "$st" in
          other-host | proxy) col=$red; icon="✖" ;;
          unleased | no-expected) col=$yel; icon="●" ;;
          *) col=""; icon="✔" ;;
        esac
        [ "$st" = ok ] && icon="${grn}✔${rst}" || icon="${col}${icon}${rst}"
        printf ' %s %-11s %-28s %-16s %7s  %s\n' "$icon" "$st" "$role" "$ip" "$n" "$note"
      done
  fi

  if [ $((p_miss + p_extra + p_drift)) -gt 0 ] || [ "$n_dang" -gt 0 ]; then
    echo; printf ' %sPOLICY FINDINGS%s\n' "$bold" "$rst"
    sed "s/^/  ${red}missing in Vault${rst}   /" "$a/pol-missing.txt"
    sed "s/^/  ${red}extra in Vault${rst}     /" "$a/pol-extra.txt"
    sed "s/^/  ${red}content differs${rst}    /" "$a/pol-drift.txt"
  fi

  [ $((findings - s_other - s_proxy - ip_mismatch)) -gt 0 ] && printf '\n %sTo fix: vault-access --fix (dry run), then --fix --apply. If it keeps drifting, the Vault host is not running the latest config (docs/VAULT-APPROLES.md, Converging).%s\n' "$dim" "$rst"
  echo; printf ' %s%s finding(s)%s' "$bold" "$findings" "$rst"
  if [ "$findings" -eq 0 ]; then printf '  %sVault matches the repo%s\n\n' "$grn" "$rst"; else printf '  %s(exit 1)%s\n\n' "$dim" "$rst"; fi
  [ "$findings" -eq 0 ]
}


# ---- --fix: converge live Vault to the declaration ----------------------------------------------
# Does by hand what the vault-policies service on the Vault host does on every deploy: write the
# policies (fmt-ed, like the module), then the roles. Dry run unless --apply. It only creates and
# updates; it never deletes (a deleted role locks its host out), it prints the commands instead.
fix() {
  gather_live
  build_rows
  local p r todo_pol todo_role payload="$a/payload.json"
  cat "$a/pol-missing.txt" "$a/pol-drift.txt" | sort -u >"$a/pol-todo.txt"
  jq -r '.[] | select(.state == "missing" or .state == "drift") | .role' "$a/rows.json" >"$a/role-todo.txt"
  todo_pol=$(wc -l <"$a/pol-todo.txt"); todo_role=$(wc -l <"$a/role-todo.txt")

  echo
  if [ "$apply" -eq 1 ]; then echo " Converging live Vault to the repo (--apply)"; else echo " Dry run: nothing is changed. Add --apply to write."; fi
  echo " ────────────────────────────────────────────────────────────────────────────────────────"

  # policies first: roles point at them
  while read -r p; do
    [ -n "$p" ] || continue
    if grep -qx "$p" "$a/pol-missing.txt"; then printf '  policy  %-44s create\n' "$p"; else printf '  policy  %-44s update (content differs)\n' "$p"; fi
    if [ "$apply" -eq 1 ]; then
      cp "$policy_dir/$p.hcl" "$a/fmt.hcl"; vault policy fmt "$a/fmt.hcl" >/dev/null 2>&1 || true
      vault policy write "$p" "$a/fmt.hcl" >/dev/null
    fi
  done <"$a/pol-todo.txt"

  while read -r r; do
    [ -n "$r" ] || continue
    jq -c --arg r "$r" '.[$r] | (.settings // {}) + {token_policies: (.token_policies // [])}' "$a/declared.json" >"$payload"
    printf '  role    %-44s %s\n' "$r" "$(jq -r --arg r "$r" '.[] | select(.role == $r) | if .state == "missing" then "create" else "update policies (\(.note))" end' "$a/rows.json")"
    [ "$apply" -eq 1 ] && vault write "auth/approle/role/$r" "@$payload" >/dev/null
  done <"$a/role-todo.txt"

  if [ $((todo_pol + todo_role)) -eq 0 ]; then echo "  nothing to do: live Vault already matches the repo"; fi

  # things we deliberately do not touch
  if [ -s "$a/pol-extra.txt" ] || jq -e '[.[] | select(.state == "unmanaged")] | length > 0' "$a/rows.json" >/dev/null; then
    echo; echo " Not touched (delete only if you are sure nothing still uses them):"
    jq -r '.[] | select(.state == "unmanaged") | "  vault delete auth/approle/role/\(.role)"' "$a/rows.json"
    sed 's|^|  vault policy delete |' "$a/pol-extra.txt"
  fi

  if [ "$apply" -eq 1 ]; then
    echo; echo " Re-checking live Vault..."
    audit
  else
    echo
    [ $((todo_pol + todo_role)) -gt 0 ] && echo " $todo_pol policy write(s) and $todo_role role write(s) pending. Re-run with --fix --apply."
    true
  fi
}

if [ "$mode" = "audit" ]; then audit; exit $?; fi
if [ "$mode" = "fix" ]; then fix; exit $?; fi

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

# Static DHCP leases: the source of each host's expected address (MicroVMs by MAC, other hosts by hostname).
# Read straight from the lease files; evaluating the router host to get them is far too slow.
lease_files=()
if [ "$leases_glob" != "none" ]; then
  # (no `compgen`: the minimal bash used for the package does not have it)
  mapfile -t lease_files < <(find "$root/$(dirname "$leases_glob")" -maxdepth 1 -name "$(basename "$leases_glob")" 2>/dev/null | sort)
  if [ ${#lease_files[@]} -eq 0 ]; then
    echo "no lease files match '$leases_glob' (relative to $root)." >&2
    echo "Pass --leases GLOB for your layout, or --leases none to derive expected addresses from $(basename "$expected_extra") only." >&2
    exit 1
  fi
fi
# Leases generated from host records (`fleet`) are { zone = [ lease ]; }; flatten them in with the hand-kept ones.
gen_expr="[]"
if [ -f "$root/$generated_leases" ]; then
  gen_expr="builtins.concatLists (builtins.attrValues (import $root/$generated_leases))"
fi
nix eval --impure --json --expr "(builtins.concatLists (map import [ ${lease_files[*]} ])) ++ ($gen_expr)" >"$work/leases.json"
echo '{}' >"$work/extra.json"
if [ -f "$expected_extra" ]; then nix-instantiate --eval --strict --json "$expected_extra" >"$work/extra.json"; fi

first="${hosts[0]}"
nix eval --impure --json --expr "
  let
    c = (builtins.getFlake \"$flake\").nixosConfigurations.\"$first\";
    va = (import $lib_file { lib = c.pkgs.lib; }).vaultAccess;
  in va.render {
    mount = \"$mount\";
    hosts = builtins.fromJSON (builtins.readFile $work/hosts.json);
    leases = builtins.fromJSON (builtins.readFile $work/leases.json);
    expected-extra = builtins.fromJSON (builtins.readFile $work/extra.json);
  }" \
  >"$work/result.json"

jq -r '.policies | keys[]' "$work/result.json" | while read -r name; do
  jq -j --arg n "$name" '.policies[$n]' "$work/result.json" >"$work/out/$name.hcl"
done
mkdir -p "$work/generated"
jq -j '.mapping' "$work/result.json" >"$work/generated/service-policies.nix"
jq -j '.ipsMapping' "$work/result.json" >"$work/generated/host-ips.nix"

case "$mode" in
  show)
    echo "# expected source address(es) of $show_host: $(jq -r --arg h "$show_host" '.ips[$h] // [] | if length == 0 then "none known" else join(", ") end' "$work/result.json")"
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
    if [ -f "$ips_file" ]; then diff -u "$ips_file" "$work/generated/host-ips.nix" || rc=1
    else echo "missing: $ips_file"; rc=1; fi
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
    cp "$work/generated/host-ips.nix" "$ips_file"
    echo "wrote $(find "$work/out" -name '*.hcl' | wc -l) policies, $(basename "$mapping_file") ($(jq '.hosts | length' "$work/result.json") hosts) and $(basename "$ips_file") ($(jq '.ips | length' "$work/result.json") names)"
    ;;
esac
