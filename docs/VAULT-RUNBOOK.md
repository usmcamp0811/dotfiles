---
type: Runbook
title: Vault runbook - day-to-day operations
description: Step-by-step procedures for working with Vault in an fmf flake - the mental model, checking health, adding a host, changing what a host can read, narrowing or removing a policy, replacing and retiring a role, rotating credentials, and recovering when something breaks.
tags: [vault, approle, runbook, operations]
status: draft
---

# Vault runbook

How to do the common jobs with Vault in a flake that uses fmf. Background and the migration plan are in
[Vault AppRoles](VAULT-APPROLES.md); the module options are in the
[vault module README](../modules/nixos/services/vault/README.md); the policy generator is
[`vault-access`](../packages/scripts/vault-access/README.md).

Every procedure has the same shape: **change the repo, check it, deploy, make hosts pick it up, verify,
and know the way back.** Nothing here asks you to `vault write` a role or policy by hand, except to
converge a Vault that has not caught up with the repo yet ([Converge](#converge-live-vault-with-the-repo)).

`status: draft`. The commands for the audit and `--fix` are the ones the tool documents. Commands that
are plain Vault CLI (secret-id rotation, accessor listing) are standard Vault but were not exercised
through this repo's tooling; they are marked.

## The model in six lines

| Thing | What it is | Where it lives |
|---|---|---|
| **Policy** | A list of paths and what may be done on them. | `<vault-dir>/policies/*.hcl`, loaded by the `vault-policies` service on the Vault host. A policy with no file is deleted. |
| **AppRole** | A login identity for one host. Carries a list of policy names. | `<vault-dir>/approles.nix` (`fmf.services.vault.approles`), written by the same service. |
| **role-id / secret-id** | The host's credentials for its role. | Issued by hand, copied to `/persist/system/var/lib/vault/<name>/` on the host (on a MicroVM's hypervisor, then shared in). **Never in Nix.** |
| **vault-agent service** | A host service that logs in with those credentials and renders secrets to files or environment. | `fmf.services.vault-agent.services.<name>` in the host's config. Unit: `detsys-vaultAgent-<name>.service`. |
| **`svc-*` policy** | One generated policy per vault-agent service, granting exactly the secrets its templates read. | `<vault-dir>/policies/svc-*.hcl`, written by `vault-access`. Do not edit. |
| **Generated map** | `host -> [svc-...]`. A role named like a host gets those policies automatically. | `<vault-dir>/generated/service-policies.nix`, written by `vault-access`. |

Two facts explain most surprises:

1. **A token's policies are fixed when the token is issued.** Changing a role changes the *next* login,
   not the token an agent is already holding. After you change a role, restart that host's
   vault-agent services so they log in again.
2. **Removing a role from `approles.nix` does not remove it from Vault** while `prune-approles` is off.
   It becomes `UNMANAGED` and keeps whatever policies it had. To make a role stop working, declare it
   with `token_policies = []`, or delete it in Vault.

## Setup on your workstation

```bash
export VAULT_ADDR=https://vault.example.lan   # your Vault's address
vault login                                   # a token that can read auth/approle/role/* and sys/policies/acl/*
```

`vault-access` is an fmf package. From the downstream repo root:

```bash
nix run --inputs-from . fmf#vault-access -- --audit --brief
```

(or put `fmf#vault-access` in your shell and call `vault-access`). It needs `VAULT_ADDR` and a token for
`--audit` and `--fix`, and nothing but the repo for `--check` and `--show`.

## Check health

```bash
vault-access --audit --brief          # live Vault against the repo; only what needs attention
vault-access --audit                  # everything, including roles that are fine
vault-access --check                  # are the committed svc-* policies and maps up to date? (no Vault needed)
```

`--audit` is read-only and exits 1 on drift. The state of each role:

| State | Meaning | What to do |
|---|---|---|
| `ok` | Live role matches the repo. | Nothing. |
| `missing` | Declared in the repo, not in Vault. | The Vault host has not applied the repo yet: [Converge](#converge-live-vault-with-the-repo). |
| `drift` | Policy list differs; the note says what to add and remove. | Same. |
| `unmanaged` | In Vault, not in the repo (created by hand, or a legacy role). | Decide: declare it, or [retire it](#replace-or-retire-a-role). |
| `dangling` | The role names a policy that does not exist. | Fix the name, or add the policy file. |
| `inert` | The role exists but no secret-id has been issued, so nothing can log in with it. | Expected for a role you created for a host not yet set up, or one you have retired. |

The note column also says which roles can already drop a broad policy (`has its svc policies`) and which
are `legacy name: no host mapping, still broad`.

To also see **where logins actually come from** (run on the Vault host, which has the audit log):

```bash
sudo tail -n 300000 /var/log/vault_audit.log | vault-access --audit --audit-log - --brief
```

`proxy` means Vault is seeing your reverse proxy instead of the client (see
[Client addresses behind a proxy](VAULT-APPROLES.md#client-addresses-behind-a-proxy)); `other-host` means a
role is in use from a machine that belongs to a different identity, which is a misplaced credential.

## Add a host (or a service) that needs secrets

1. **Write the config.** Enable the module that uses vault-agent, or declare
   `fmf.services.vault-agent.services.<name>` with its templates. The templates already say which secret
   paths are needed (`{{ with secret "..." }}`); that is the whole access specification.
2. **Regenerate the policies.** From the repo root:

   ```bash
   vault-access --show <host>     # what this host would get; writes nothing
   vault-access                   # writes policies/svc-*.hcl and generated/*.nix
   git diff <vault-dir>           # review it: a new svc-* file, or a changed one, is the access change
   ```

   A changed `svc-*` file for a service you did not touch means a module now reads more (or fewer)
   secrets. That is what the review is for.
3. **Name the role for the host.** The agent reads `role-id` and `secret-id` from
   `/var/lib/vault/<name>/`, and `<name>` is the host's name. You do not list the role in `approles.nix`
   unless it needs a hand-written policy as well; the generated map creates it.
4. **Deploy the Vault host** so the policy and role exist (`journalctl -u vault-policies -b | grep -E
   'Writing (polic|approle)'` shows them). If it is a MicroVM with `restartIfChanged` off, restart it
   deliberately; that **seals Vault** until auto-unseal runs, so do it at a quiet moment.
5. **Issue the credentials** (once per host; never through Nix):

   ```bash
   vault read  -field=role_id  auth/approle/role/<name>/role-id
   vault write -f -field=secret_id auth/approle/role/<name>/secret-id
   # -> /persist/system/var/lib/vault/<name>/{role-id,secret-id}   mode 0400, owner root
   ```

   For a MicroVM, the directory lives on its hypervisor and is shared into the guest; create it first
   (`systemd.tmpfiles` rule `d /persist/system/var/lib/vault/<name> 0700 root root -`).
6. **Deploy the host and start its agent services.** Verify:

   ```bash
   systemctl status detsys-vaultAgent-<service>
   journalctl -u detsys-vaultAgent-<service> -b --no-pager | tail -20   # rendered, or permission denied?
   vault-access --audit --brief                                         # the role is no longer `inert`
   ```

## Change what a host can read

The rule is: **change the template, not the policy.** Add or remove the secret in the module or service
that reads it, run `vault-access`, review the `svc-*` diff, commit, deploy the Vault host, and restart the
host's agent services.

If something reads Vault in a way the generator cannot see (a script or CLI, the policy agent, Kubernetes
auth management, a service account, an appliance), write a policy file by hand in `<vault-dir>/policies/`
and attach it in `approles.nix` next to the generated ones:

```nix
my-role.token_policies = ["my-hand-written-policy"];   # the generated svc-* ones are added automatically
```

Keep hand-written policies small and named for what they allow. If you find yourself writing one that a
vault-agent template could express, use the template.

Policy names are **lowercase** (Vault lowercases them, and the module deletes any policy whose file name
does not match literally).

## Narrow or remove a broad policy

Use this to take a wide policy off roles that have narrower generated ones, one host at a time. It is
safe to start because policies are additive: the generated `svc-*` policies are attached **alongside** the
broad one first, so nothing breaks until the broad one is actually removed.

**Before you start**

```bash
vault-access --check                  # generated policies are current
vault-access --audit --brief          # note the roles that say "has its svc policies: can drop <policy>"
```

A role is ready when its host's `svc-*` policies are generated and attached. A role that is **not**
ready (no host in the flake, no vault-agent services, or a use the generator cannot see) needs a
hand-written narrow policy first; do not remove the broad one from it on a guess.

**Per host (start with one low-risk, non-critical host)**

1. In `approles.nix`, remove the broad policy from the role. For a role named like a host with nothing
   else to add, delete its line: the generated map creates the role with just its `svc-*` policies.
   Keep a line only for hand-written policies. If the role must stay but do nothing, set
   `token_policies = []`.
2. Check the change is only what you meant. Evaluate the file before and after and compare, so a typo
   cannot silently widen or strip a role:

   ```bash
   # from the repo root; the old copy needs ./generated beside it, so extract the whole directory
   old=$(mktemp -d); git archive HEAD <vault-dir> | tar -x -C "$old"
   nix-instantiate --eval --strict --json "$old/<vault-dir>/approles.nix" | jq -S . > "$old/old.json"
   nix-instantiate --eval --strict --json  <vault-dir>/approles.nix       | jq -S . > "$old/new.json"
   diff "$old/old.json" "$old/new.json"
   ```

   Every changed role should differ by the one policy you removed, and the set of roles should be the
   same. No role should *gain* a policy. (This evaluates the file alone, so it does not need the Vault
   host to be built, which can be very large.)
3. Deploy the Vault host and confirm `vault-access --audit --brief` shows the role as `ok`.
4. On the host, restart its agent services so they log in with the new policy list:

   ```bash
   sudo systemctl restart $(systemctl list-units 'detsys-vaultAgent-*' --plain --no-legend | awk '{print $1}')
   ```

5. Verify the host still renders everything:

   ```bash
   journalctl -u 'detsys-vaultAgent-*' --since '-10min' --no-pager | grep -iE 'permission denied|error'
   systemctl --failed
   ```

   Also exercise whatever the host does with those secrets (a service that starts from them, a
   certificate that renews). Absence of errors in the agent log is not proof for a secret that is only
   read occasionally.
6. Wait a day for anything that reads on a timer, then move to the next host.

**If something breaks:** a `permission denied` for a path means that host reads something no template
declares. Either add the secret to the right template (then `vault-access`) or, for a read the generator
cannot see, attach a small hand-written policy. To restore access immediately, put the broad policy back
on that one role, deploy the Vault host (or `vault-access --fix --apply`), and restart the host's agents.
The agent log names the path that was denied.

**When no role carries the broad policy** (`vault-access --audit` shows it on nothing, and the live role
list agrees), delete its `.hcl` file. Do this last and as its own change: removing a policy file deletes
it from Vault, and any role still naming it silently loses access.

## Replace or retire a role

Use this to move a host from a wrongly named role to a correctly named one, or to stop a role from
working. There are no aliases: you create the correctly named role and move the host to it.

1. **Find out who uses the old role.** Resolve each host's `role-id` file against the live role table
   ([Which role does a host actually use?](VAULT-APPROLES.md#which-role-does-a-host-actually-use)), and
   look at recent logins by role name in the audit log. Do not retire a role on a guess.
2. **Create the new one** (named for the host, as in [Add a host](#add-a-host-or-a-service-that-needs-secrets)):
   declare or generate it, deploy the Vault host, issue credentials, install them on the host, restart
   the host's agent services, and confirm it renders.
3. **Confirm the old role is idle.** Watch the audit log for the old role name over a period that covers
   your slowest timer. If it still appears, find the host and finish its move first.
4. **Make it inert.** Declare the old role with `token_policies = []`, deploy, and watch for failures. A
   login still succeeds but can read nothing, so a host that was missed shows up as `permission denied`
   instead of a vanished role.
5. **Delete it** once nothing complains: remove it from `approles.nix`, and delete the live role
   (`vault delete auth/approle/role/<old>`), or turn on `prune-approles` once every role is accounted for.

Never retire the role the policy agent logs in with (`vm-vault` in Campground). If `vault-policies`
cannot log in, nothing in this runbook can be applied.

## Rotate or revoke credentials

Standard Vault commands, not exercised through this repo's tooling:

```bash
# new secret-id for a host, install it, restart the host's agents
vault write -f -field=secret_id auth/approle/role/<name>/secret-id

# revoke an old one: list accessors, destroy the one you no longer want
vault list auth/approle/role/<name>/secret-id
vault write auth/approle/role/<name>/secret-id-accessor/destroy secret_id_accessor=<accessor>
```

Issue and install the new secret-id **before** destroying the old one, or the host's next login fails. To
lock a host out entirely, destroy its secret-ids (or make its role inert); tokens it already holds live
until they expire or are revoked (`vault token revoke -mode=path auth/approle/login` is blunt and logs
out everyone, so avoid it).

`role-id` is an identifier, not a secret, but treat the file like any credential, and never paste a
secret-id into a ticket, a chat or the repo.

## Converge live Vault with the repo

The `vault-policies` service applies the repo on every start of the Vault host, so after a deploy the audit
should be clean. If it is not, work out why before forcing it:

1. **Is the Vault host running the new system?** Compare `readlink /run/current-system` there with the
   store path you built. Two common causes: a MicroVM whose `restartIfChanged` is off (restart it from
   its hypervisor; this seals Vault), or a `deploy --boot` that installed the generation but has not
   activated it.
2. **Did the service run?**

   ```bash
   systemctl status vault-policies
   journalctl -u vault-policies -b --no-pager | grep -E 'Writing polic|Writing approle|UNMANAGED|not found|rror'
   ```

   It exits quietly if the policy agent's `role-id` / `secret-id` files are missing and retries every 30
   seconds if a write fails.
3. **Is the audit reading the same revision?** `--audit` reads your working tree.

To apply now, without waiting for the service:

```bash
vault-access --fix            # dry run: every policy and role it would write
vault-access --fix --apply    # policies first, then roles; re-runs the audit
```

`--fix` only creates and updates. It never deletes, because a deleted role locks its host out; it prints the
exact `vault delete` commands for what it left alone.

## Rules that save you

- **Never delete the role the policy agent uses.** It is the only way the repo reaches Vault.
- **Restarting the Vault host seals Vault.** Plan for it; agents elsewhere retry.
- **`prune-approles = true` is last.** It deletes every undeclared role at the next policy run, instantly
  breaking any host still using one. Turn it on only when the audit is clean and the audit log shows no
  undeclared role in use.
- **One host at a time, least critical first**, and keep the change reviewable: a policy narrowing is one
  commit, a policy file deletion is another.
- **Secrets never go in Nix.** `role-id` / `secret-id` are installed by hand; the store is world-readable.
- **Do not edit `svc-*.hcl` or `generated/*.nix`.** Change the template or the module and re-run
  `vault-access`; the drift check fails otherwise.
- **If an audit result surprises you, read the audit log before changing anything.** It records the role
  name and source address of every login.

## Troubleshooting

| Symptom | Likely cause | Check |
|---|---|---|
| Agent log: `permission denied` on a path | The role has no policy for it: a template changed and `vault-access` was not re-run, or a broad policy was removed from a host that reads something the generator cannot see. | The path is in the log. Is it in a template? Run `vault-access --show <host>`. |
| Policy was changed but the host still has the old access | The agent holds a token issued before the change. | Restart `detsys-vaultAgent-<service>` on the host. |
| Audit says `missing` or `drift` right after a deploy | The Vault host is not running the new system, or `vault-policies` failed. | [Converge](#converge-live-vault-with-the-repo). |
| Audit says `unmanaged` for a role you deleted from the repo | Pruning is off, so Vault kept it. | Make it inert or delete it in Vault. |
| `vault-access --check` fails in CI | A module or host change altered what a service reads, or a host moved. | Run `vault-access`, review the diff, commit. |
| A role was removed from `approles.nix` but the host still logs in | It is still live and still holds its policies. | `vault read auth/approle/role/<name>`; declare it with `token_policies = []`. |
| `vault-policies` is silent and nothing is applied | The policy agent's `role-id` / `secret-id` files are missing. | `journalctl -u vault-policies -b`; see the vault module README. |
| Audit shows `proxy` for many roles | Vault sees the reverse proxy, not the client. | `fmf.services.vault.trusted-proxies`; see [Client addresses behind a proxy](VAULT-APPROLES.md#client-addresses-behind-a-proxy). |
