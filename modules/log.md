# Update Log

## 2026-11-14
* **Strata**: added `fmf.services.strata` (pinned CUDA engine build), `fmf.services.strata-client`, the Qwen3.6 model package and the OpenCode `strata` provider. The engine has not been built to completion and no inference has run; see the README's known limitations.

## 2026-11-01
* **Circuit Breaker**: added `fmf.services.circuit-breaker` (server, flake-driven sync, agent) with its exporter, reconciler and end-to-end tests. See CIRCUIT-BREAKER.md and the runbook in docs.

## 2026-10-19
* **Initialization**: Adopted Open Knowledge Format v0.2: added frontmatter to 43 existing documents and generated `index.md` files with `okf`.
