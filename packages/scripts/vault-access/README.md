# vault-access

Derives one least-privilege Vault policy **per service** from what the `fmf.services.vault-agent`
templates in your hosts actually read, and writes a map of which host needs which policies.

Enabling a module that uses vault-agent already states the secrets it needs (every template contains
`{{ with secret "<path>" }}` or `{{ with pkiCert "<path>" }}`). This tool reads that from the
*evaluated* config instead of anyone writing the policy by hand, so policies cannot drift from the
modules that use them.

## Use

Run it from the root of the flake that defines your `nixosConfigurations`:

```bash
vault-access                  # write svc-*.hcl policies and generated/service-policies.nix
vault-access --check          # exit non-zero if the committed files are stale (for CI)
vault-access --show vm-media  # print the policies one host needs, write nothing
vault-access --audit          # scoreboard: compare LIVE Vault with the repo (read-only)
vault-access --audit --brief  # same, but only the roles that need attention
sudo tail -n 300000 /var/log/vault_audit.log | vault-access --audit --audit-log - --brief
                              # also reconcile the source addresses Vault actually saw (see docs)
vault-access --fix            # dry run: what it would write to bring live Vault in line with the repo
vault-access --fix --apply    # do it (policies, then roles); never deletes
```

From a downstream flake that has `fmf` as an input:

```bash
nix run --inputs-from . fmf#vault-access -- --check
```

Defaults match Campground's layout; override with `--mount`, `--hosts-dir`, `--vault-dir`, `--leases`,
`--flake` (see `vault-access --help`).

## What it produces

- `<vault-dir>/policies/svc-<service>.hcl`: one policy per vault-agent service, granting exactly the
  secrets its templates read. Names are lowercase (Vault lowercases policy names).
- `<vault-dir>/generated/service-policies.nix`: `host -> [ "svc-..." ]`, for attaching the policies to
  the AppRole named like the host.
- `<vault-dir>/generated/host-ips.nix`: `name -> [ ips ]`, where each host is expected to connect to Vault
  from. Derived from the static DHCP leases (`--leases`, default `blue-ridge/router/*-leases.nix`):
  a MicroVM by its MAC, other hosts by lease hostname. A hand-kept `<vault-dir>/expected-ips.nix` is
  merged on top for what leases cannot say. Used by `--audit` (and, later, to bind roles to addresses).

All three are meant to be committed, so a module change that widens access shows up as a reviewable diff.

## How it works

The rules (what a service reads, naming, capabilities) live in
[`lib/vault-access`](../../../lib/vault-access/default.nix), exposed as `lib.fmf.vaultAccess`. It is pure
Nix with regression tests (`tests.nix`), so this CLI and downstream checks share one implementation.

- `extractHost` reads one host's evaluated `config.fmf.services.vault-agent`, collects every template
  (inline `text` or `source` file) and pulls out the `secret` / `pkiCert` calls.
- `render` turns every host's result into the policies and the host -> policies map.

This script only evaluates the hosts, one `nix eval` at a time with a few in parallel so memory stays
small, hands the results to `render`, and writes the files.

## Auditing live Vault

```bash
export VAULT_ADDR=https://vault.lan.aicampground.com
vault login                       # a token that can read auth/approle/role/* and sys/policies/acl/*
vault-access --audit              # from the downstream repo root
```

Prints a scoreboard (roles, policies, credentials, progress off the broad `campground` policy) and a
per-role table, problems first. It is read-only and exits 1 on drift (a declared role or policy
missing from Vault, a role created by hand, changed policies or content, a role pointing at a policy
that does not exist), so it can run from cron. `--brief` hides the roles that are fine. Colour only on a
terminal; `NO_COLOR=1` turns it off.

## Keeping it fresh

- fmf's CI runs `vault-access` right after it bumps a downstream repo's `fmf` lock and commits the
  result (`update_fmf_in_gitea` in `.gitlab-ci.yml`).
- A downstream repo should also run a drift check built on `lib.fmf.vaultAccess` (Campground:
  `checks/vault-access`), which catches changes made only downstream.

## Limits

- It only sees vault-agent **templates**. CLI or script access, the Vault policy agent, Kubernetes
  auth management and service accounts still need hand-written policies.
- A path that is neither under the KV mount nor PKI becomes an `UNRESOLVED` comment and grants nothing.
- The whole fleet is evaluated every run, because policy names depend on every host.

## More

The model, naming rules and the migration plan are in
[docs/VAULT-APPROLES.md](../../../docs/VAULT-APPROLES.md). The `approles` option that consumes the
output is in the [vault module](../../../modules/nixos/services/vault/README.md).
