---
type: Guide
title: Vault AppRoles - one role per host, least-privilege policies
description: How AppRoles are declared in Nix next to policies, the one-role-per-host naming rule, how to audit live roles against the flake, and the phased plan for replacing the broad campground policy with generated per-service policies.
tags: [vault, approle, security]
status: draft
---

# Vault AppRoles

Policies are already deterministic: `.hcl` files are loaded by the `vault-policies` service of
[`fmf.services.vault`](../modules/nixos/services/vault/README.md), and policies without a file are
deleted. AppRoles were not. They were created by hand (`vault write auth/approle/role/<x> ...`), so the
only record of which roles exist, and what they can do, was Vault itself.

This guide covers the target state, the audit that tells you how far a real Vault is from it, and the
order to get there. `status: draft`: the module change below was evaluated in isolation (see
[What has been tested](#what-has-been-tested)); nothing here has been applied to a live Vault yet.

## Target state

1. **One AppRole per host, named for the host**: `chesty`, `vm-media`, `vm-k8s-worker-daly`. The name
   is the same string as the credential directory `/var/lib/vault/<name>/` that the host's
   `fmf.services.vault-agent` reads `role-id` and `secret-id` from. A role is never shared by two hosts.
2. **Every role is declared in Nix** (`fmf.services.vault.approles`), next to the policies it
   uses. Vault holds no role that the flake does not know about.
3. **Roles get small purpose policies, not one broad one.** A role's `token_policies` is the list of
   things that host needs, such as `kv-cloudflare-read` or `pki-grpc-farm-issue`, and nothing else. The
   catch-all `campground` policy is retired.
4. **`role-id` / `secret-id` stay out of Nix.** They are issued once per host and copied into
   `/persist/system/var/lib/vault/<name>/` (see the host's README).

## Declaring roles

```nix
# vm-vault/default.nix
fmf.services.vault = {
  approles = import ./vault/approles.nix;   # { vm-media.token_policies = ["vm-media"]; ... }
  # prune-approles = false;                  # default: report only
};
```

Per-role options: `token_policies` (list of policy names) and `settings` (any other AppRole role
parameter, e.g. `token_ttl`, `token_bound_cidrs`, `secret_id_ttl`, `secret_id_num_uses`). Behaviour,
update semantics and the pruning warning are in the
[module README](../modules/nixos/services/vault/README.md#approles).

## Auditing

### The scoreboard

One command compares live Vault with the repo and prints a report, problems first:

```bash
export VAULT_ADDR=https://vault.lan.aicampground.com
vault login                  # needs read on auth/approle/role/* and sys/policies/acl/* (admin has it)
vault-access --audit         # from the downstream repo root; --brief hides the roles that are fine
```

It shows the role and policy counts, any declared role or policy missing from Vault, roles created by
hand, policy lists or policy content that differ from the repo, roles that point at a policy that does
not exist, roles with no secret-id issued yet, and progress off the broad `campground` policy (with
how many roles already carry their `svc-*` policies and can drop it). It is read-only and exits 1 when
it finds drift, so it can run from cron. The commands below are the manual equivalents.

### When the audit shows drift: converging

The `vault-policies` service on the Vault host writes the policies and roles on every start, so after
a deploy the audit should be clean. If it is not, the usual reason is that **the Vault host is not
running the new configuration**, not that the config is wrong. Check, in this order:

1. **Is the new system actually active?** On the Vault host compare `readlink /run/current-system`
   with `nix path-info .#nixosConfigurations.<vault-host>.config.system.build.toplevel` from the repo.
   Two common ways it is not:
   - The Vault host is a **MicroVM** and its `microvm.vms.<name>.restartIfChanged` is off. Deploying
     the hypervisor builds the new VM but does not restart it, so it keeps running the old system
     until `systemctl restart microvm@<name>` on the hypervisor. Restarting Vault seals it; expect a
     short outage while auto-unseal runs, and agents on other hosts retry.
   - It was deployed with `deploy --boot`, which installs the generation but only activates it at the
     next boot. Activate in place instead (`deploy` without `--boot`, or `nixos-rebuild switch`).
2. **Did the service run, and did it succeed?**

   ```bash
   systemctl status vault-policies
   journalctl -u vault-policies -b --no-pager | grep -E 'Writing polic|Writing approle|UNMANAGED|not found|rror'
   ```

   It exits quietly (status 0) if the policy agent's `role-id` / `secret-id` files are missing, and
   retries every 30 seconds if a write fails.
3. **Is the audit looking at the same revision?** `--audit` reads `approles.nix` and the policies from
   your working tree; if the Vault host was built from an older commit, that is the difference.

To converge now without waiting for the service, run the same writes by hand:

```bash
vault-access --fix            # dry run: lists every policy and role it would write
vault-access --fix --apply    # policies first, then roles; then re-runs the audit
```

`--fix` only creates and updates. It never deletes: a deleted role locks its host out. Roles or
policies that exist in Vault but not in the repo are listed with the exact `vault delete` commands, to
run once you have checked nothing uses them (or set `prune-approles` once the audit is otherwise
clean). If `--fix --apply` succeeds but the service keeps failing, the problem is the service, and
step 2 is where to look.

### What Vault has, and what is undeclared

After a deploy, the service logs every role it did not find in Nix:

```bash
journalctl -u vault-policies | grep -E 'UNMANAGED|Removing undeclared'
```

To see the live roles directly (needs a token that can read `auth/approle/role/*`):

```bash
export VAULT_ADDR=https://vault.lan.aicampground.com
for r in $(vault list -format=json auth/approle/role | jq -r '.[]'); do
  vault read -format=json "auth/approle/role/$r" |
    jq -c --arg r "$r" '{role:$r, policies:.data.token_policies, ttl:.data.token_ttl,
      cidrs:.data.token_bound_cidrs, sid_ttl:.data.secret_id_ttl, sid_uses:.data.secret_id_num_uses}'
done
```

### Which role does a host actually use?

A host holds only a `role-id` UUID, never the role name, so the flake cannot say which role a host
logs in with. Build the table once from Vault, then look each host's file up in it:

```bash
# role name -> role-id, for every live role
for r in $(vault list -format=json auth/approle/role | jq -r '.[]'); do
  printf '%s %s\n' "$(vault read -field=role_id auth/approle/role/$r/role-id)" "$r"
done > /tmp/role-ids.txt

# on a host (or the VM's share on its hypervisor): which role is this?
id=$(sudo cat /var/lib/vault/<name>/role-id)            # MicroVM: /persist/system/var/lib/vault/<name>/role-id on the host
grep "^$id " /tmp/role-ids.txt
```

A host whose file resolves to a role with a different name (a legacy `adguard` for `vm-adguard`) is a
rename candidate. A live role that no host resolves to is an orphan candidate. `role-id` is an
identifier, not a secret, but treat the file as you would any credential: do not paste secret-ids.

### Declared hosts versus declared roles (from the flake)

Every host with a vault-agent has a `role-id = "/var/lib/vault/<name>/role-id"` line. Comparing those
names with `approles` shows hosts that have no role of their own:

```bash
rg -o --no-filename 'role-id\s*=\s*"/var/lib/vault/([^/"$]+)/role-id"' -r '$1' systems | sort -u
```

A host that builds its path from a variable (for example `vm-airflow-worker-*` via `nodeName`) will not
appear in this list; check those by hand.

## Client addresses behind a proxy

Vault records, and checks `token_bound_cidrs` / `secret_id_bound_cidrs` against, the address of whatever
connected to it. If agents reach Vault through a reverse proxy, that address is the **proxy's**, for every
client behind it: the audit log cannot say which host a login came from, and an IP binding on a role
checks the proxy and so protects nothing. Settle this before relying on either.

**Measure it.** The file audit device records `request.remote_address` and, as plain text,
`auth.metadata.role_name` on every authenticated event, so no lookups are needed:

```bash
L=/path/to/vault_audit.log
tail -n 300000 "$L" | jq -R -r 'fromjson? | select(.type=="response" and (.auth.metadata.role_name // null) != null)
  | [.auth.metadata.role_name, .request.remote_address] | @tsv' | sort | uniq -c | sort -rn
```

`fromjson?` skips the torn first and last lines of a tail, which plain `jq` aborts on. Any role whose
address is the proxy's is going through it. (In Campground this showed fifteen roles arriving as the
`lan-traefik` address, and a few arriving directly.)

**Fix it.** Tell the Vault module which proxies to trust. It makes the listener honour their
`X-Forwarded-For`, from those addresses only:

```nix
fmf.services.vault.trusted-proxies = ["<proxy ip>/32"];   # a list; empty (the default) trusts none
```

The module builds the listener text on top of the nixpkgs default (`tls_min_version`), because setting
`services.vault.listenerExtraConfig` replaces that default, and sets both `x_forwarded_for_reject_*`
flags to `false`. Downstream only supplies the address, ideally from the same source of truth as the
proxy's own address (Campground reads it from the proxy's static DHCP lease, so they cannot drift).

Tested against a throwaway Vault running this listener block, with one trusted proxy and with two: a
forwarded client address is what the audit log records and what bound CIDRs are checked against, and a
forged header from an address that is not a trusted proxy is ignored (the real peer address is used).
The `reject` flags are explicit so a request is never refused over the header; Vault 2.0.3 refused none
of those cases even at its defaults, so they guard against a version whose defaults differ.

Changing the listener restarts `vault.service`, which seals Vault until auto-unseal runs. Afterwards re-run
the query above: only the roles whose own agent runs on the proxy should still show the proxy's address.

## Expected addresses and the IP audit

Once Vault sees real client addresses, each role can be checked against where its host is supposed to
connect from. `vault-access` derives that, reports it in `--audit`, and can compare it with what the
audit log actually recorded.

**Where "expected" comes from.** The static DHCP leases, read as plain files (evaluating the router host
to get them is far too slow), joined to the hosts:

- a MicroVM by the MAC of its interface, which is exact (lease hostnames usually drop the `vm-` prefix);
- any host also by lease hostname, including `<host>-wifi` / `<host>-eth` variants, so a host on two
  networks gets every address it may use;
- every lease hostname, lower-cased, as an identity of its own, so a legacy role name that was never
  renamed (`lan-traefik`, `ata-nuc`) resolves too.

The result is committed as `generated/host-ips.nix` and regenerated by `vault-access` like the policies,
so the drift check covers it. For what leases cannot say (the router itself, a host on a dynamic
address), a hand-kept `expected-ips.nix` is merged on top. Only list an address you have confirmed
belongs to that host. A MicroVM with no lease for its MAC is best fixed with a static lease, which also
pins the address.

**In the scoreboard and table.** Each role shows its expected address(es) and an `IP-BOUND` state, from
its live `token_bound_cidrs` and `secret_id_bound_cidrs`:

| State | Meaning |
|---|---|
| `bound` | the CIDRs are exactly the expected addresses |
| `unbound` | an expected address is known and nothing is bound |
| `mismatch` | bound, but to something else, including a binding that leaves out one of the host's addresses and would lock it out |
| `n/a` | no expected address is known and nothing is bound |

**Against the audit log.** `vault-access --audit --audit-log FILE` reads the file audit device's log
(`FILE` or `-` for stdin; a tail is enough, and `--since` limits it to events after a deploy). The role
name is plain text on every authenticated event, so each (role, source address) pair is classified:

| State | Meaning |
|---|---|
| `ok` | an address the role's host is expected to use |
| `proxy` | the reverse proxy's address: Vault is not seeing the real client (is `trusted-proxies` deployed?) |
| `other-host` | an address that belongs to a **different** identity in the lease table: a credential in use on another host |
| `no-expected` | nothing is known about where this role should connect from |
| `unleased` | the role has expected addresses, but this one is in no lease (dynamic or unpinned) |

`other-host` and `proxy` count as findings (exit status 1); the others are information. From the Vault
host, which has the log at `/var/log/vault_audit.log`:

```bash
sudo tail -n 300000 /var/log/vault_audit.log | vault-access --audit --audit-log - --brief
```

In Campground this found a MicroVM logging in with another host's role (its address belonged to a
different VM's lease), and a macvtap VM whose logins came from its hypervisor's address.

**Binding a role to its address** (enforcement) is the next step, and it only makes sense for roles whose
observed address already matches the expected one. A binding is applied when a token or secret-id is
used at login, so existing tokens (with a long TTL) are not affected until their agent logs in again.

## Migration plan

Each phase leaves Vault working. Do not start a phase until the previous one is applied and verified.

### Phase 0: record what exists (no behaviour change)

Declare every live role exactly as it is (`token_policies` copied from Vault, nothing renamed) and
deploy. The first run is a no-op: it re-writes identical roles. From then on `journalctl -u
vault-policies` reports any role created outside Nix.

### Phase 1: map hosts to roles

Run the [role-id lookup](#which-role-does-a-host-actually-use) for every host and write the result down
(host, role it resolves to, whether the names match). This is the evidence for phases 2 and 5; do not
rename or delete a role on a guess.

### Phase 2: one role per host

For each host whose role name differs from its directory name, or has no role at all:

1. Declare `approles.<host>` with the **same** `token_policies` the host has today.
2. Deploy the Vault host; the role now exists.
3. Issue credentials and install them on the host (never through Nix):

   ```bash
   vault read  -field=role_id  auth/approle/role/<host>/role-id
   vault write -f -field=secret_id auth/approle/role/<host>/secret-id
   # -> /persist/system/var/lib/vault/<host>/{role-id,secret-id}, mode 0400, root
   ```

4. Restart the host's vault-agent and confirm it renders its secrets.
5. Only then remove the legacy role from `approles` (it becomes `UNMANAGED`), and revoke it later in
   phase 5.

Optionally pin a readable role-id (`vault write auth/approle/role/<host>/role-id role_id=<host>`) so
the file on disk is the host name and phase 1 disappears. This is a Vault feature used here as a
suggestion; it has not been tried on this Vault.

### Phase 3: break the broad policy into per-service policies

Almost every role carries `campground`, which grants wide read/write across the KV mount, the PKI
mounts and more, so any host can read every host's secrets. Replace it with **one policy per service
that needs a secret**, and give each role the policies of the services its host runs:

```text
service (gitea secrets, pia-vpn, mealie, ...) --1:1-->  policy svc-<service>
host runs services A, B, C                    ------->  role <host> carries svc-A, svc-B, svc-C
```

1. **Derive, do not hand-write.** What a service reads from Vault is already in its evaluated config:
   every `fmf.services.vault-agent.services.<name>` template contains `{{ with secret "<path>" }}` or
   `{{ with pkiCert "<path>" }}`. A module that enables such a service therefore already states the
   access it needs. fmf's `vault-access` package ([`packages/scripts/vault-access`](../packages/scripts/vault-access/README.md)) evaluates every host
   (one `nix eval` at a time), extracts those calls, and writes:

   - `vault/policies/svc-<service>.hcl`, one policy per vault-agent service, granting exactly the
     secrets its templates read;
   - `vault/generated/service-policies.nix`, the map `host -> [ svc-... ]` that `approles.nix` uses to
     attach them to the role named like the host.

   ```bash
   vault-access                    # (re)generate both, run from the downstream flake root
   vault-access --show vm-media    # print the policies one host needs, write nothing
   vault-access --check            # exit non-zero if the committed files are stale (CI)
   # without installing it:  nix run --inputs-from . fmf#vault-access -- --check
   ```

   Both are committed, not computed at deploy time. A module change that widens a service's access, or
   moves a service onto another host, shows up as a diff to review instead of taking effect silently
   on the next Vault deploy. The Vault host only ever evaluates the committed files, so its build does
   not evaluate the other hosts.

   Keeping them fresh is automatic, in three layers that all use the same rules, which are one
   pure-Nix library (`lib.fmf.vaultAccess`, [`lib/vault-access`](../lib/vault-access/default.nix), with
   regression tests in `tests.nix`):

   - **fmf CI.** After it bumps the downstream repo's `fmf` lock (`update_fmf_in_gitea` in
     `.gitlab-ci.yml`), it runs `vault-access` in that clone and commits the result in the same
     bot commit. A failure there is a warning, not a blocker, so it cannot stall the bump.
   - **A drift check** in the downstream repo (Campground: `checks/vault-access`) derives the policies
     from the real host configs at evaluation time and fails if they differ from the committed
     files. This is what catches a downstream-only change (a host or service enabled in Campground),
     which does not trigger the fmf pipeline. It evaluates every host, so budget about a minute and
     several GB; it skips itself while the locked fmf predates the feature.
   - **By hand**, when the check fails: run `vault-access` and commit.
2. **Naming.** `svc-` plus the vault-agent service name, **lowercased**: Vault lowercases policy names,
   and the module's `remove-unknown-policies` compares names literally, so a mixed-case file name
   would be deleted on the next run. When the same service name reads different secrets on different
   hosts (`k3s` on the control-plane node also reads `argocd`; `rkvm` vs `rkvm_gray`), each distinct
   set is its own policy, named after its secrets (`svc-k3s--argocd-repo-k3s`), so no host is granted
   another host's extras.
3. **Rules the generator applies:**
   - KV v2 template paths (`secret/campground/<x>`) become `secret/campground/data/<x>` with `read`;
     a template that already spells `.../data/<x>` is kept as is (never `data/data`).
   - PKI `.../issue/<role>` gets `update`; other PKI paths (`.../cert/ca`) get `read`.
   - Each KV path also gets `read` on `sys/internal/ui/mounts/<path>` (mount-version discovery for
     the agent; returns no secret data). Whether the agent needs it has not been confirmed.
   - A path outside the KV mount and not PKI is written as an `UNRESOLVED` comment and grants
     nothing, so it is visible instead of silently wrong.
   - `auth/approle/login` is not granted: login is unauthenticated.
   - A service whose templates are conditional (the gitea module only declares its secrets when it
     uses a non-sqlite database or a mailer) yields a policy only on hosts where they are declared.
4. **What it cannot see.** Only vault-agent templates. Access from a CLI or script, the policy agent
   (`vm-vault`), Kubernetes auth management (`vm-k8s-control-0`) and service accounts such as
   `gitlab-runner` still need a hand-written policy attached next to the generated ones.

Policies are additive, so generating them and attaching them **alongside** `campground` cannot break a
login. Then, per host:

1. Deploy Vault with the generated policies attached; confirm the host still renders everything.
2. Remove `campground` from that host's role and restart the host's vault-agent services (a token's
   policies are fixed when it is issued). Repeat per host.
3. Delete `campground.hcl` when no role references it.

Keep `admin` out of ordinary hosts. It is needed only by the role the policy agent logs in with.

### Phase 4: tighten the role itself

Do [Client addresses behind a proxy](#client-addresses-behind-a-proxy) first, or the CIDRs below are checked
against the proxy. Once policies are narrow, add per-role limits in `settings`: `token_bound_cidrs` to the host's
address, a finite `token_ttl`, `secret_id_ttl`/`secret_id_num_uses` where a host can re-fetch. Do this
per host and watch vault-agent, since a wrong CIDR locks the host out.

### Phase 5: enforce

When `journalctl -u vault-policies` shows no `UNMANAGED` lines, set `prune-approles = true`. From then
on Vault matches the flake: an undeclared role is deleted at the next policy run. Never prune while the
role the policy agent uses (`vm-vault`) is not declared.

## What has been tested

- The `approles` / `prune-approles` options were evaluated against the module on its own (a stub
  `lib.fmf`, no full host). With `approles = {}` the generated service script is unchanged. With roles
  declared the script writes each role and audits the list; `prune-approles` switches the audit from
  logging to `vault delete`. `bash -n` and shellcheck show no problems in the generated section.
- The policy derivation reproduces a real fleet's 57 committed policies byte for byte, and
  `lib/vault-access/tests.nix` covers its rules, including the expected-address join (mutating a rule
  makes a test fail).
- `vault-access --audit` was run against a fake `vault` serving a fixture, including a break in each
  way it reports. The audit-log reconciliation was run on an audit log rebuilt from a real Campground
  query (same roles, addresses and proportions) and reproduced the hand analysis: 14 matching,
  2 `other-host`, 1 `unleased`, 4 `no-expected`.
- `trusted-proxies` was checked against a throwaway Vault, and confirmed in Campground: after the
  deploy a proxied request is recorded with the client's own address, not the proxy's.
- **Not tested:** `--audit` against a real Vault (the fake follows `vault read` / `list` output as
  documented), whether the real `vault read` reports bound CIDRs as `a.b.c.d` or `a.b.c.d/32` (both are
  handled), the policy agent's permissions beyond what its `admin` policy implies, the pinned role-id
  suggestion, or enforcing bound CIDRs on any role. Treat phase 2 onward as unverified until done on
  one low-risk host first.
