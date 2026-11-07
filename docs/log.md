# Update Log

## 2026-11-07
* **Host model spec (draft)**: added HOST-MODEL.md, a specification for one `fmf.host` record per machine (interfaces and VLAN zones, lifecycle, MicroVM placement and storage, boot order, DNS, exposure, Vault, topology) and a fleet function that derives leases, DNS, port forwards, Vault roles, hypervisor hosting and boot ordering from it. Specification only; nothing is implemented.
* **Host model, phase 0**: added the `fmf.host` / `fmf.network.zones` options (modules/nixos/system/host) and `lib.fmf.fleet` with tests. Declares data only; no consumers yet. Verified against Campground with seven pilot records (results in HOST-MODEL.md).

## 2026-11-06
* **Vault AppRoles**: added `fmf.services.vault.approles` and `prune-approles` so AppRoles are declared in Nix like policies (report-only by default), and VAULT-APPROLES.md covering the one-role-per-host rule, auditing live roles, and the migration plan. Phase 3 replaces the broad `campground` policy with one generated `svc-<service>` policy per vault-agent service, derived from the evaluated templates (`vault-access`, an fmf package).

## 2026-11-03
* **MicroVM troubleshooting**: added MICROVM-TROUBLESHOOTING.md covering the stale store overlay (whiteouts that hide real store paths), emergency-mode diagnosis, duplicate `boot.kernelParams`, NetworkManager taking static NICs, Snowfall's default `wheel` membership, Vault netrc sidecars, gid 10000 and agent forwarding.

## 2026-11-01
* **Circuit Breaker**: added `fmf.services.circuit-breaker` (server, flake-driven sync, agent) with its exporter, reconciler and end-to-end tests. See CIRCUIT-BREAKER.md and the runbook in docs.

## 2026-10-19
* **Initialization**: Adopted Open Knowledge Format v0.2: added frontmatter to 13 existing documents and generated `index.md` files with `okf`.
