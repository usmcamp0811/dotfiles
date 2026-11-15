---
type: NixOS Module
title: Strata inference and OpenCode
description: "Strata (GPU VRAM + system RAM MoE inference) as a pinned NixOS service, the remote client module, and the OpenCode provider that uses it."
resource: ./default.nix
tags: [services, strata, ai, cuda]
---

# Strata inference and OpenCode

[Strata](https://github.com/Niko1221/Strata) (MIT) is an inference engine that keeps the experts of a
Mixture-of-Experts model it can fit in VRAM and computes the rest on the CPU from a pinned RAM copy. It serves an
OpenAI-, Anthropic- and Responses-compatible API.

* `fmf.services.strata` runs the server on the GPU host (sledge).
* `fmf.services.strata-client` gives a workstation the OpenCode provider and the API key.
* `fmf.tools.agentic-ai.strata` is the Home Manager provider the client module configures.

None of them is enabled by default. Strata is **an additional backend**: llama.cpp, Ollama and the cloud providers
are unchanged, and the default model and agent assignments are not touched.

## What Strata can and cannot run

Strata documents three model families: DeepSeek V4.1-Flash, Qwen3.8-Flash-Next and Qwen3.6-35B-A3B. Its engine
selects a path from the GGUF architecture; it is not a general GGUF runner, and a matching filename does not prove
compatibility (upstream `docs/AI_SETUP.md`). Against this repository's llama.cpp catalog:

| Catalog model | On Strata? | Why |
| --- | --- | --- |
| `qwen3.6-35b-a3b` | **Yes, with a different file** | Strata's `qwen36` path reads Unsloth's **MTP** GGUFs (`unsloth/Qwen3.6-35B-A3B-MTP-GGUF`) and documents only UD-Q4_K_XL, UD-Q6_K_XL and Q8_0. The llama.cpp catalog's file is UD-IQ3_S from the plain GGUF repository: not a documented Strata artifact. |
| `gpt-oss-20b` | No | Not a Strata family. Stays on llama.cpp. |
| `qwen3.5-9b` | No | Not a Strata family. Stays on llama.cpp. |
| `qwen3-coder-30b-a3b` | No | Not a Strata family. Stays on llama.cpp. |
| `devstral-small-2` | No | Not a Strata family. Stays on llama.cpp. |
| Qwen3.8-Flash-Next | Supported upstream, **not packaged here** | See below. |

The Strata catalog is `lib.fmf.strataModels` and holds exactly the models verified above:

| Id (what `/v1/models` reports) | File | Size | Context here |
| --- | --- | ---: | ---: |
| `qwen3.6-35b-a3b-ud-q4_k_xl` | `Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf` | 22,853,663,008 B | 65,536 |

Revision `5bc3e238d916f48a861bac2f8a1990a0e9b7e98d`; size and SHA-256 equal those pinned in Strata v0.2.13.1's
`setup.py`. This is a separate Nix store file from the llama.cpp one: **it is a second 22.9 GB download**, not a reuse,
because the formats differ.

### Qwen3.8-Flash-Next (evaluated, not implemented)

Upstream's recommended pack is ISTA-DASLab; IQ3_S needs 54.8 GB of RAM+VRAM (it fits 128 GB) and is the
slowest and highest quality of the family. It is not packaged because it is a different engine path with a
multi-shard pack, a draft layer that Strata's first start downloads (about 6 GB), prepared tokenizer/pack/profile
steps and a different run-config schema. None of that can be reproduced as a pure, hash-pinned artifact set without
running it on the GPU first. Adding it means a second catalog entry, its shard and MTP artifacts, and a second
run-config generator in the module; the instance would still serve one model at a time.

## One instance, one model

A Strata server answers every request with its loaded model whatever `model` the client sends (`serve/server.py`:
"Other names are still served"). So an instance advertises exactly one model, under the id it reports, and OpenCode
lists exactly one. To serve another model, run a second instance on another port; two instances on one 16 GB GPU
will not fit at once, which is what the load/unload controls below are for.

## Server

```nix
fmf.services.strata = {
  enable = true;
  host = "10.8.0.177";
  port = 18081;
  vault = { enable = true; path = "secret/campground/data/strata"; };   # or apiKeyFile = "/run/keys/strata"
  lazyLoad = true;            # start unloaded, load on first request
  idleUnloadSeconds = 300;    # give the VRAM back when idle
  minFreeVramMiB = 8192;      # answer 503 instead of fighting for VRAM
  vramReserveMiB = 1536;      # headroom for the desktop on the same GPU
  memoryMax = "64G";
};
```

* **Auth is mandatory.** The module refuses to evaluate without `apiKeyFile` or `vault.enable`. The key reaches the
  server as `$STRATA_API_KEY`, read by the launcher at start. It is never in `argv`, the unit text or the Nix store.
  The launcher refuses to start if the key is missing or not 32 to 256 printable characters.
* **Everything but `/health` requires the key** (`/v1/*`, `/metrics`, `/status`, `/props`, `/slots`). `/health` is
  open and reports status, the served model id, whether a key is required and whether the model is loaded.
* **Pinned and offline.** The engine is built from Strata commit `628f749…` (tag v0.2.13.1) with CUDA 13.0 and the
  llama.cpp commit upstream's `setup.py` pins (`3cf0325…`). The server runs with `--offline` and nothing downloads at
  start. The tokenizer is extracted from the GGUF's metadata by a Nix derivation, not at service start.
* **State vs artifacts.** Weights and the engine are store paths. Mutable state is `/var/lib/strata`
  (`tmp`, `cache`, `config`, `state`, `engine.log`), owned by the `strata` user.
* **Unit.** Dedicated `strata` user in `video` and `render`; `Restart=on-failure` with a 30 s back-off and at most
  5 starts per 15 minutes, so a refused context or missing GPU does not spin; `MemoryMax`, optional `MemoryHigh`,
  `OOMScoreAdjust=200` (this server is killed before the desktop), `LimitMEMLOCK=infinity` (the engine pins RAM).

### GPU, RAM and CPU

* **Placement is the engine's.** With `expertVramGiB = null` it keeps every expert in VRAM when they fit, otherwise
  the most-used experts on the GPU and the rest on the CPU from a pinned RAM copy ("hybrid mode"). On 16 GB the
  26 GB-class model is in hybrid mode. Upstream measured 18.75 GiB of experts pinned for UD-Q4_K_XL on a 12 GB card
  and plans 32 GB of RAM for the model; `memoryMax = "64G"` leaves half of sledge's 128 GB to everything else.
* **VRAM.** The KV cache is in VRAM at 45,056 bytes per token (2.75 GiB at 64K, 1.375 GiB at 32K), room the experts
  would otherwise use. The engine states what the sessions need and refuses a context that cannot fit, with numbers;
  lower `contextSize` then (and the client's `contextSize` to match). Each `parallel` slot adds its own cache.
* **CPU threads.** The default is one worker per physical core except the main thread's, one fewer again on CPUs
  with 17+ cores, one socket: 15 workers on the 16-core 9950X3D, one NUMA node, no NUMA split. `poolWorkers` sets it.
* **CCDs.** The 9950X3D has two CCDs, one with 3D V-Cache. Upstream's `--pool-cores` pinning does **not** apply to
  the Qwen3.6 engine ("keeps its own `--pool-workers` and default placement"), so there is no engine-side CCD pinning
  to configure. `cpuAffinity` is a blunt systemd constraint. **No CCD or thread-count setting here is benchmarked**;
  defaults are the engine's. Measure with a fresh server per value (upstream's advice) before changing them.
* **Sharing the GPU with llama.cpp.** llama.cpp's router unloads after 300 s idle; `lazyLoad` and
  `idleUnloadSeconds = 300` give Strata the same behaviour, and `minFreeVramMiB` makes a load answer 503 when
  another engine holds the memory. The NVIDIA desktop is on this GPU too, hence `vramReserveMiB`.
* **Driver.** The CUDA 13 engine needs NVIDIA driver 580 or newer; the module asserts it. sledge's pinned nixpkgs
  provides 595.71.05. Ada (sm_89) builds are compiled for `cudaArchitectures = ["89"]`. Upstream's tuned per-card
  defaults are listed for sm_86, sm_60 and sm_120; Ada works (community reports include 4070/4080 SUPER) but has no
  tuned defaults.

## Credentials and remote clients

The server's key is a Vault KV v2 secret at `secret/campground/data/strata`, field `api_key`, rendered by the Vault
Agent sidecar for the `strata` user (the same pattern as llama.cpp). Create it once:

```bash
vault kv put secret/campground/strata api_key="$(openssl rand -hex 32)"
```

The AppRole policies in `vm-vault/vault/policies/` are **generated** by `vault-access`; run it after enabling the
module so `svc-strata` and the per-user `svc-user-secrets-*--strata*` policies exist.

Clients enable `fmf.services.strata-client` (Campground: `campground.suites.strata-client`). It renders the same
key to `/var/lib/vault/users/<user>/strata_api_key` and configures Home Manager. OpenCode's wrapper exports
`STRATA_API_KEY` at start; the key is not in the Nix store. A client carries no engine, no CUDA and no weights. Traffic
goes through the LAN Traefik with TLS (`https://strata.lan.aicampground.com/v1`); the plaintext backend is limited by
`IPAddressAllow` to loopback and the proxy.

```bash
opencode --model strata/qwen3.6-35b-a3b-ud-q4_k_xl
```

**Headless OpenCode server** (`fmf.services.opencode-server`, attached with `opencode-remote`): the *server*, not the
attached TUI, calls the model providers, so the server process needs the key too. Its `environmentFiles` default
lists only the llama.cpp key, and setting the option replaces the default. A host that runs the server and wants
Strata must list both:

```nix
fmf.services.opencode-server.environmentFiles = {
  LLAMA_CPP_API_KEY = config.fmf.services.llama-cpp-client.apiKeyFile;
  STRATA_API_KEY = config.fmf.services.strata-client.apiKeyFile;
};
```

The server reads the provider list from its user's Home Manager config, which `strata-client` fills in. Models are
then chosen inside the attached session (`/models`); that attached-client behaviour has not been tested here.
Restart the server after changing providers or keys.

The provider is registered next to `ollama` and `llama-cpp` (not instead of them), with `limit.context`,
`limit.output` and the same compaction headroom as llama.cpp (`limit.input = context - output - 6144`), so
compaction still fires before the window overflows.

## Monitoring

```bash
systemctl status strata                    # unit state
journalctl -u strata -f                    # server log
tail -f /var/lib/strata/engine.log         # engine log
strata-status                              # /health, and /v1/models if you can read the key
curl -s http://10.8.0.177:18081/health     # {"status":"ok","model":…,"loaded":true|false,…}
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

`"loaded": false` is normal with `lazyLoad`/`idleUnloadSeconds` until a request arrives; the first request pays the
cold load.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Unit fails with "API key file … missing or unreadable" | The Vault key was not rendered: check `systemctl status detsys-vaultAgent-strata` and that `secret/campground/data/strata` exists and the AppRole has `svc-strata`. |
| Engine exits right after start, context numbers in the log | The context does not fit beside the experts and the reserve. Lower `contextSize` (and the client's), `parallel`, or raise nothing else. |
| 503 on a request | `minFreeVramMiB` not met: llama.cpp or the desktop holds the VRAM. Wait for llama.cpp's 300 s unload, or lower the threshold. |
| Start-limit hit | Five failed starts in 15 min. Fix the cause, then `systemctl reset-failed strata`. |
| `needs NVIDIA driver 580 or newer` at build | Pin a newer `hardware.nvidia.package`. |
| 401 | Wrong or missing key. The client's key is `/var/lib/vault/users/<user>/strata_api_key`. |

## Validation

```bash
nix build .#checks.x86_64-linux.strata-config     # module/unit/run-config/credential/refusal assertions (eval only)
nix build .#checks.x86_64-linux.strata-opencode   # provider JSON, preserved providers, no weights on clients (eval only)
nix build .#checks.x86_64-linux.strata-vm         # real pinned server under the real unit, mock engine: auth, streaming, failure modes
nix build .#strata.engine                         # the CUDA engine (long; use the farm)
# on the GPU host, after deploying (not run by CI):
strata-status
opencode --model strata/qwen3.6-35b-a3b-ud-q4_k_xl run "reply with OK"
```

The VM test uses Strata's scripted **mock engine** with tiny fake weights: it proves the service wiring, credential
handling, authentication and the API shape, not inference or GPU use.

## Known limitations

* No inference, CUDA initialisation, GPU use, RAM use or tool-call behaviour of the real engine has been exercised by
  this repository's tests; those need the GPU host. The engine's derivation evaluates, but at the time of writing it
  had **not been built to completion**: the farm builds of the CUDA 13.0 toolkit pieces failed on gRPC transfer
  errors when driven from a microVM. Build it on the GPU host (`nix build .#strata`) before relying on it.
* One model per instance; Qwen3.8-Flash-Next is not packaged (above).
* Upstream pins exact Python package versions in `requirements.txt`; this package uses nixpkgs' versions.
* `STRATA_PORTABLE=ON` (AVX2 baseline for ggml-cpu) is used so the farm build does not target the farm machine's CPU.
  A `-march=native` build on the host itself could be faster for CPU-side experts: `portable = false`, unmeasured.
* The CPU-expert, CCD and thread settings are the engine's defaults; none is benchmarked here.
* `/health` is unauthenticated and discloses the model id and load state to anyone who can reach the proxy.
* No performance comparison with llama.cpp has been run; make no speed claim until one has.
