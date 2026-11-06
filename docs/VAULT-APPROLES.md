---
type: Guide
title: Vault AppRoles - one role per host, least-privilege policies
description: How AppRoles are declared in Nix next to policies, the one-role-per-host naming rule, how to audit live roles against the flake, and the phased plan for splitting the broad campground policy.
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

### Phase 3: break the broad policy into purpose policies

Almost every role carries `campground`, which grants wide read/write across `secret/data/campground/*`,
the PKI mounts and more, so any host can read every host's secrets. Replace it with policies named for
what they allow:

1. Inventory what each host actually reads: its `fmf.services.vault-agent` templates and secrets, and
   the modules that use them. This is derived from the flake, so it is reviewable.
2. Group identical needs into one policy per capability (one KV path, one PKI issue endpoint), and add
   the `.hcl` files. Policies are additive, so a new policy cannot break anything.
3. Attach the new policies **alongside** `campground` for one host, redeploy, and confirm the host
   still renders everything.
4. Remove `campground` from that host's role. Repeat per host.
5. Delete `campground.hcl` when no role references it.

Keep `admin` out of ordinary hosts. It is needed only by the role the policy agent logs in with.

### Phase 4: tighten the role itself

Once policies are narrow, add per-role limits in `settings`: `token_bound_cidrs` to the host's
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
- **Not tested:** a run against a real Vault, the policy agent's permissions beyond what its `admin`
  policy implies, the pinned role-id suggestion, or any host's login after a rename. Treat phase 2
  onward as unverified until done on one low-risk host first.
