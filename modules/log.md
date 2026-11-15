# Update Log

## 2026-11-15
* **Strata**: added `fmf.services.strata.router` (one lazy instance per model plus a small router, so a client picks the model and the others unload), `fmf.services.strata-client.models` and `fmf.tools.agentic-ai.strata.models`. New checks: router assertions in `strata-config`, `strata-router-vm` (mock engine) and a multi-model case in `strata-opencode`. No switch between real engines has been run on a GPU.

## 2026-11-14
* **Strata**: added the Qwen3.6-35B-A3B UD-Q6_K_XL and Q8_0 models to the catalog (same pinned repository and engine path as UD-Q4_K_XL). Not run on the GPU.
* **Strata**: added `fmf.services.strata` (pinned CUDA engine build), `fmf.services.strata-client`, the Qwen3.6 model package and the OpenCode `strata` provider. The engine has not been built to completion and no inference has run; see the README's known limitations.

## 2026-11-01
* **Circuit Breaker**: added `fmf.services.circuit-breaker` (server, flake-driven sync, agent) with its exporter, reconciler and end-to-end tests. See CIRCUIT-BREAKER.md and the runbook in docs.

## 2026-10-19
* **Initialization**: Adopted Open Knowledge Format v0.2: added frontmatter to 43 existing documents and generated `index.md` files with `okf`.
