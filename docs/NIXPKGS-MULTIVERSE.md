# nixpkgs-multiverse: pinning one package version without a new flake input

## Summary

This flake now has [`nixpkgs-multiverse`](https://github.com/fzakaria/nixpkgs-multiverse)
as an input, and a small library helper, `lib.fmf.multiversePackage`, that
resolves it. The goal: when an FMF module needs one specific package at one
specific version, it no longer has to add a new pinned `nixpkgs` flake input
(`old-nixpkgs`, `pyarrow`, etc.) just to get it.

```
normal nixpkgs                       nixpkgs-multiverse
     |                                     |
     +-- coherent NixOS systems            +-- explicit package version requests
     |                                         |
     +-- normal packages                       +-- Traefik 3.7.13 (if ever pinned)
                                                +-- future one-off version pins
```

- **`nixpkgs`** (`github:nixos/nixpkgs/release-26.05`) stays the package set
  every NixOS system in this flake is built from. Nothing about that
  changes.
- **`nixpkgs-multiverse`** is an escape hatch for a single leaf
  package/tool that needs an exact version nixpkgs' current channel does
  not carry. It is not a second coherent package set, and it is not meant
  to feed anything tightly coupled to the running system (kernel modules,
  libc, a server + its extensions that must be built against the exact
  same libpq/headers, etc).

## The helper: `lib.fmf.multiversePackage`

Defined in [`lib/multiverse/default.nix`](../lib/multiverse/default.nix).

```nix
{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  services.traefik.package = lib.fmf.multiversePackage {
    inherit inputs pkgs;
    name = "traefik";
    version = "3.7.13";
  };
}
```

- `system` is inferred from `pkgs.stdenv.hostPlatform.system` -- never
  hardcoded to `x86_64-linux`.
- `inputs` must be the caller's own `inputs` special arg (the one already
  passed into every NixOS module), carrying a `nixpkgs-multiverse` input.
  The helper does not close over this flake's own `inputs`, so it works
  the same way whether a module is evaluated directly by this flake or by
  a downstream flake (e.g. Campground) that consumes these modules and
  supplies its own `inputs.nixpkgs-multiverse`.
- Resolution is lazy: only the one nixpkgs revision that shipped
  `name`@`version` is ever fetched/evaluated. Listing "does this version
  exist" (which the error message below does) costs nothing -- it reads a
  pre-built JSON index, not a nixpkgs checkout.
- Unknown package/version fails loudly, from nixpkgs-multiverse itself:

  ```
  error: multiverse: no revision provides traefik 3.7.11.
  Known versions: 1.3.8 1.4.4 ... 3.7.10 3.7.12 3.7.13
  ```

### When to use it (and when not to)

Use it for a single, independent leaf package that doesn't need to share a
dependency closure with the rest of the system -- a CLI tool, a
self-contained server binary like Traefik, etc.

Do **not** use it for:

- Anything that must match another package built from the same coherent
  `pkgs` (e.g. PostgreSQL extensions that must link against the exact
  `postgresql` server derivation already in use).
- A whole set of related packages that should move together (that's what
  `channels.unstable` / `channels.old-nixpkgs` already exist for).
- Anything this flake's own overlays patch. A multiverse-resolved package
  comes from a separate, independently-fetched nixpkgs revision and does
  **not** get this flake's `overlays/*` applied to it (see the Traefik
  caveat below).

## First consumer: `fmf.services.traefik`

[`modules/nixos/services/traefik/default.nix`](../modules/nixos/services/traefik/default.nix)
gained two options:

```nix
fmf.services.traefik = {
  enable = true;
  version = null; # default; see below
  package = null; # explicit override, wins over `version`
};
```

Resolution order in the module:

1. `package`, if set -- used as-is.
2. Otherwise `version`, if set -- resolved via
   `lib.fmf.multiversePackage { name = "traefik"; version = cfg.version; }`.
3. Otherwise `pkgs.traefik` -- the Traefik from this flake's own coherent
   `nixpkgs`.

### Why `version` defaults to `null`, not `"3.7.13"`

There is a real, current security requirement: **CVE-2026-85594**
([GHSA-m6wx-622r-48r9](https://github.com/traefik/traefik/security/advisories/GHSA-m6wx-622r-48r9)),
a `crossProviderNamespaces` bypass in Traefik's Kubernetes Ingress
provider (a namespace-restricted tenant could attach an operator-owned
middleware to its own Service and recover credentials that middleware
injects). Verified via the NVD API (`CVE-2026-85594`) and the vendor GHSA:

- **Affected:** Traefik `>= v3.7.1, <= v3.7.10`.
- **Fixed in:** `v3.7.11` (released 2026-08-19).

As of this writing, `nixpkgs` pinned by this flake (`release-26.05`)
**already ships Traefik 3.7.13** (verified with
`nix eval --raw .#nixosConfigurations.vm-lan-traefik.pkgs.traefik.version`),
which is later than the fix and additionally covers everything fixed in
`v3.7.12` and `v3.7.13` -- including a Critical HTTP/3 NTLM
connection-reuse bug ([GHSA-qqjf-53cj-pwvv](https://github.com/traefik/traefik/security/advisories/GHSA-qqjf-53cj-pwvv))
disclosed after `3.7.11` shipped. So the security requirement is already
satisfied by the plain `pkgs.traefik` this module already forces.

Given that, defaulting `version` to a concrete string and always routing
through multiverse would:

- Duplicate a whole extra nixpkgs revision's closure for a version already
  available for free from the coherent channel, and
- **Silently drop this flake's own Traefik plugin vendoring** --
  `overlays/overrides`'s `postInstall` bakes the CloudflareWarp and
  fail2ban local-mode plugins into `pkgs.traefik`'s `$out/bin/plugins-local`.
  A multiverse-resolved package is a separate build that never sees that
  overlay, so any host relying on those plugins (e.g. `vm-pub-traefik` via
  `fmf.suites.public-hosting`, which configures
  `http.middlewares.cloudflarewarp`) would silently lose them.

So `version` defaults to `null` (use `pkgs.traefik`, already patched), and
exists so a host can pin an exact version explicitly -- e.g. if nixpkgs
ever regresses to an older Traefik, or a fix lands upstream before it
reaches nixpkgs:

```nix
fmf.services.traefik.version = "3.7.13";
```

Hosts that do this and also rely on the CloudflareWarp/fail2ban vendoring
should instead pass `package` with that vendoring re-applied on top of the
multiverse-resolved derivation, rather than relying on `version` alone.

### Verifying provenance

```console
$ nix eval --raw .#nixosConfigurations.vm-lan-traefik.config.services.traefik.package.version
3.7.13
```

To see the multiverse path resolve a *different* version end-to-end (this
does not change the default; it is just a way to prove the mechanism), set
`fmf.services.traefik.version` on a host and re-run the same command -- the
returned `package.version` will match, and
`config...package.drvPath` will point at a distinct derivation built from
the pinned nixpkgs-multiverse revision instead of this flake's own
`nixpkgs`.

## Reviewed nixpkgs pins: what's safe to migrate

Per the request to look for nixpkgs inputs that exist only to get one
(or a few) specific package version(s):

| Input | What it's for | Verdict |
| --- | --- | --- |
| `unstable` (`nixos-unstable`) | `.follows`-ed by many other inputs (hyprland, poetry2nix, crystal-forge, nix-ai, nixhelm, deploy-rs, comma, sbomnix, nix2sbom, pre-commit-hooks, neorg-overlay, ...) **and** backs a large, coherent set of packages in `overlays/unstable-channel` and `overlays/development` (paperless, n8n, nextcloud30, immich, netbird family, yazi+plugins, python311 toolchain, mlflow, etc). | **Keep.** Feeds many other inputs and a large coherent package set; not a single-package pin. |
| `old-nixpkgs` (`nixos-25.05`) | `ckb-next`, `postgresql16Packages`, `postgresql14Packages`, `neovide`, `mkYarnPackage`, `yarn2nix-moretea` (see `overlays/campground-packages`). | **Unclear -- do not migrate yet.** `postgresql16Packages`/`postgresql14Packages` are re-exported as the *global* `pkgs.postgresql16Packages`/`pkgs.postgresql14Packages` attributes, which hosts combine with `services.postgresql.package = pkgs.postgresql_16` (from the *main*, non-`old-nixpkgs` channel) for `extraPlugins` (see Campground's `reckless` host). Extensions must be built against the exact same PostgreSQL server derivation they'll be loaded into; migrating this to multiverse (or even auditing whether the current setup is already mismatched) needs its own dedicated investigation, not a drive-by change here. `neovide`/`mkYarnPackage`/`yarn2nix-moretea`/`ckb-next` are more plausible one-off candidates for a future multiverse migration, but that's a separate, deliberate change -- not made here. |
| `pyarrow` (pinned commit `e8b4c13b...`) | Only `arrow-cpp_11` in `overlays/development`, feeding a `poetry2nix` fork (`TyberiusPrime/poetry2nix/pyarrow_fix`) that likely depends on the exact shape of that Arrow/Python packaging at that revision. | **Unclear -- do not migrate.** A C++ library with a Python-binding-compatibility dependency on a specific poetry2nix fork; swapping its source nixpkgs revision needs verification this doesn't change the package's shape in a way that fork depends on. |
| `nix-patched` (`github:NixOS/nix/2.34.5`) | `fmf.nix.package` (Nix daemon itself), pinned for CVE-2026-39860 (see `docs/CVE-2026-39860-MITIGATION.md`). | **Keep as-is; not a nixpkgs pin.** This is the upstream Nix project's own flake, not nixpkgs -- it provides the canonical, patched Nix release build directly from its source, which is more appropriate for the Nix package manager itself than whatever build nixpkgs happens to produce at some revision. Out of scope for a nixpkgs-multiverse migration. |

No existing pin was migrated in this change; Traefik is the only current
`multiversePackage` consumer, and it defaults to *not* using it (see
above).

## Validation

```console
# Confirm nixpkgs already ships the patched version (why `version` defaults
# to null):
$ nix eval --raw .#nixosConfigurations.vm-lan-traefik.pkgs.traefik.version
3.7.13

# Provenance, as shipped (default: pkgs.traefik):
$ nix eval --raw .#nixosConfigurations.vm-lan-traefik.config.services.traefik.package.version
3.7.13

# Full host evaluates end-to-end with the new module options in place:
$ nix build .#nixosConfigurations.vm-lan-traefik.config.system.build.toplevel --dry-run

# flake.lock only gained the new input:
$ nix flake lock --update-input nixpkgs-multiverse
```

See the PR/commit description for the temporary-override test that proved
`lib.fmf.multiversePackage` resolves a distinct, real Traefik build
(`3.7.12`, verified via the built binary's own `traefik version` output)
end-to-end through the module.
