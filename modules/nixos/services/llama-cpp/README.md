---
type: NixOS Module
title: llama.cpp inference and OpenCode
description: "The llama.cpp service module with an on-demand model router, and the client module that gives OpenCode its provider and credential."
resource: ./default.nix
tags: [services, llama-cpp, ai]
---

# llama.cpp inference and OpenCode

`fmf.services.llama-cpp` extends the NixOS llama.cpp service. It supports the
existing single-model configuration and an optional on-demand model router.
`fmf.services.llama-cpp-client` adds the provider and distributes its credential
to an existing Home Manager user. Neither module is enabled by default.

## Models in the Nix store

The four independent `pkgs.fmf` packages fetch single GGUF files using immutable
Hugging Face revisions and published LFS SHA256 hashes. There is no mutable
`main` download, runtime HF download, conversion, or token required.

| Package suffix after `llama-model-` | Bytes | Default context |
| --- | ---: | ---: |
| `gpt-oss-20b-mxfp4` | 12,109,566,624 | 32768 |
| `qwen36-35b-a3b-ud-iq3-s` | 13,676,723,168 | 32768 |
| `qwen3-coder-30b-a3b-ud-q3-k-xl` | 13,806,312,608 | 32768 |
| `devstral-small-2-24b-q4-k-m` | 14,334,446,752 | 32768 |

The shared lazy catalog is `lib.fmf.llamaCppModels { inherit pkgs; }`.
`router.models` defaults to this catalog. Model paths in the generated preset
retain all four files in the system closure, even though only one model loads
at a time. Remote client JSON includes only IDs, names, and limits: clients do
not acquire weights. The total is approximately 54 GB, plus llama.cpp/CUDA and
build dependencies. Normal Nix store permissions mean local users can read the
weights; the API credential is never a store object.

Qwen3.6 is the Unsloth **UD-IQ3_S** artifact, not plain IQ3_S. The official
Devstral base model card says Apache-2.0 but the selected quant repository's
metadata says `other`. Its package is conservatively marked unfree rather than
claiming redistribution rights; hosts selecting it need `allowUnfree`. Other
selected model cards specify Apache-2.0. Pins, hashes, sizes and sources are in
the individual package definitions.

## Server

```nix
fmf.services.llama-cpp = {
  enable = true;
  cudaSupport = true;
  host = "192.0.2.10";
  port = 18080;
  router.enable = true;
  vault = {
    enable = true;
    path = "secret/data/example/llama-cpp";
    field = "api_key";
    kvVersion = 2;
  };
};
```

This follows the existing `fmf.services.vault-agent.services.llama-cpp` pattern.
The sidecar renders the file with mode 0400 for the static `llama-cpp` service
user and shares its private `/tmp` with the service. The server receives only
the rendered file path, not the key in argv or the store, and rejects a missing
or malformed key before startup. A rendered-key change restarts the service.
There is no separate credential-installation service or new Vault admin logic.
The existing Vault Agent settings/AppRole and read policy must be provisioned.
The per-service Agent configuration explicitly inherits the address and
`role-id`/`secret-id` file paths from
`fmf.services.vault-agent.settings.vault`, just like `user-secrets` does. An
enabled Agent without those settings is rejected during Nix evaluation.
For KV v2, `vault.path` must be the API path containing `/data/`; `kvVersion`
selects the response nesting (`.Data.data`), not a different secret mount.

For an externally provisioned root-readable file instead, leave Vault disabled
and set `apiKeyFile = "/run/secrets/inference-key";`. That path is passed through
systemd `LoadCredential`. Paths must be strings outside `/nix/store`; do not
interpolate secret contents or use `builtins.readFile`.

Router requests select the model via the OpenAI `model` field. Model IDs are
`gpt-oss-20b`, `qwen3.6-35b-a3b`, `qwen3.5-9b`, `qwen3-coder-30b-a3b`, and `devstral-small-2` on the main service; `ternary-bonsai-2-27b`, `ternary-bonsai-2-27b-q2_0` and `inkling-2-mini` are served by their own runtimes (below).
`--models-max 1` limits loaded models, `--parallel 1` limits request slots, and
`--offline` prevents runtime model downloads. Presets use embedded Jinja chat
templates, explicit contexts, 256/128 batch/microbatch sizes, automatic GPU
offload/Flash Attention, a 2048 MiB fit margin, one context checkpoint per slot,
and five-minute idle sleep. Bounding checkpoints trades prefix-reuse speed for
less SWA/recurrent state-cache overhead; it does not reduce the context window.
Switching has cold-load latency and may wait for a busy model.

This uses the pinned nixpkgs llama.cpp (currently b9190), not an unverified
floating latest release. Router mode is experimental upstream. Do not expose
it on an untrusted/public network. The inference API key is also required for
inference, but `/health` is deliberately public upstream.

### GPU limits

These are agent-sized contexts, **not guaranteed full-GPU 16 GiB fits**.
Model file size is not VRAM usage; KV/recurrent state, CUDA buffers, display
workloads and other applications need headroom. Automatic fit can move layers
to CPU RAM. Qwen Coder and dense Devstral can need substantial CPU offload at
32K and can be much slower than GPT-OSS on the same card.
No projector is included: Qwen3.6 and Devstral are configured for text only.
Measure on the actual GPU and validate streaming/tool calls before depending
on any model for unattended agent work.

All four profiles use 32K in both server presets and OpenCode metadata, with
2048 output tokens. The earlier GPT-OSS 8K window left only about 6K usable in
OpenCode 1.19.4; fixed instructions and tool
schemas can exceed that even for a short message and trigger repeated
compaction. Keep automatic compaction enabled; do not merely advertise more
context than the server allocates. Restart the server and OpenCode and use a
fresh session after changing the limit. A model switch no longer silently
shrinks the advertised window to 2K–8K. Switching still changes tokenizers and
templates, so actual model/tool behavior needs live validation. No real-model
memory/performance result is implied by the CPU router test.

## Client

```nix
fmf.services.llama-cpp-client = {
  enable = true;
  user = "alice";
  baseURL = "https://llama.example.internal/v1";
  vault.path = "secret/data/example/llama-cpp";
};
```

The user must already enable `fmf.tools.agentic-ai` with OpenCode in Home Manager.
The module reuses `fmf.services.user-secrets`: it adds `llama_api_key` and
overrides only that file's source template to the dedicated shared secret.
The existing copy service installs
`/var/lib/vault/users/<user>/llama_api_key` as mode 0400 for that user.

Home Manager's `fmf.tools.agentic-ai.llamaCpp` can also be configured directly
with `enable`, `baseURL`, and an externally provisioned `apiKeyFile`. The
OpenCode wrapper reads the file at process startup into `LLAMA_CPP_API_KEY`;
the JSON uses `{env:LLAMA_CPP_API_KEY}`. It works with GUI/non-zsh launches and
does not prevent cloud usage if the file is temporarily missing. Existing
cloud and agent defaults are unchanged. Select a model with `/models` or:

```bash
opencode --model llama-cpp/gpt-oss-20b
```

### Context overflow and compaction loops

A 32K window overflows if one tool result (a large read or grep) adds ~15K tokens at
once: llama-server answers `request (N tokens) exceeds the available context size`
before the agent can react, and the compaction request, which sends the whole
history, overflows too. Two settings keep a session inside the window:

- `llamaCpp.compactionHeadroom` (default 6144) sets each model's OpenCode
  `limit.input` to context minus max output minus the headroom (24576 for a 32K
  model), so compaction starts while there is still room for the summary request.
- `llamaCpp.toolOutput.maxLines` / `maxBytes` (default 500 / 16384) cap one tool
  result (OpenCode's own defaults are 2000 / 51200). They apply to every model in
  that OpenCode while llama.cpp is enabled.

To diagnose a loop, look for the overflow message with
`journalctl -u llama-cpp | grep 'exceeds the available context'`.

Quit and restart OpenCode after configuration changes or key rotation. Keeping
the credential in an environment variable does not hide it from the same user
or root, but prevents embedding it in the store or command-line arguments.

## Validation

```bash
nix build --no-link 'path:.#checks.x86_64-linux.llama-cpp'
```

The isolated test starts the actual CPU llama-server with tiny fake model paths,
verifies presets are listed without loading weights, checks unauthenticated
inference is rejected and tests systemd credential delivery. It neither contacts
Vault nor downloads weights. It does not validate GPU memory fit, actual model
generation/tool behavior, production Vault permissions, or site proxy routing.
It also starts a worker for each real model ID with fake bytes, checking that
all preset arguments parse and reach the GGUF loader. Invalid-byte failures are
intentional; the fixture bounds the request and resets the router between cases.
It starts the main service and both extra runtimes with the real CPU builds of the
PrismML fork and of upstream b12651, so each preset (including the Bonsai and Inkling
sampling, `fit = off`, `no-op-offload` and the projector key) is parsed by the build
that will serve it; it checks that each router lists only its own models, that
each unit executes its own binary with the same credential and bounds, and that a
runtime restarts alone while the main unit restarts all of them. It still loads no
real weights: inference, VRAM and long-prompt behavior are not validated by it.

Additional checks require no Vault server or live credential files:

```bash
nix build --no-link \
  .#checks.x86_64-linux.llama-cpp-vault-config \
  .#checks.x86_64-linux.agentic-ai-activation
```

They verify nonempty per-service AppRole configuration, the shared private
namespace and KV v2 template nesting, and mock optional skill installs under
strict-shell/dry-run conditions. Remote-skill installation failures warn rather
than abort Home Manager unless `fmf.tools.agentic-ai.remoteSkillsStrict = true`.

## Models that need another llama.cpp build (`runtimes`)

Three models do not run on the nixpkgs llama.cpp (b9190), so they sit on **other builds, each its own router**. A router
worker is the router binary itself, so one router cannot mix builds: `fmf.services.llama-cpp.runtimes.<name>` adds
`llama-cpp-<name>.service`, a router on its own port with the main unit's hardening, GPU access, user, API key (the
same Vault file or credential), host restrictions and `--models-max 1 --offline`. The main service and its five models
are untouched. A runtime restarts alone; stopping or restarting `llama-cpp.service` stops or restarts them all, and
starting it starts them (they unload after the same 300 s idle timeout).

| Model id | File | Runtime | Needs |
| --- | --- | --- | --- |
| `ternary-bonsai-2-27b` | `Ternary-Bonsai-2-27B-PTQ1_0.gguf`, 5.95 GB | `prism` | PrismML's fork, `pkgs.fmf.llama-cpp-prism` |
| `ternary-bonsai-2-27b-q2_0` | `Ternary-Bonsai-2-27B-Q2_0.gguf`, 7.63 GB | `mainline` | upstream llama.cpp b11556 or newer, `pkgs.fmf.llama-cpp-mainline` |
| `inkling-2-mini` | `Inkling-2-Mini-UD-IQ3_XXS.gguf`, 11.66 GB, plus `mmproj-F16.gguf`, 0.64 GB | `mainline` | upstream, b12619 or newer |

```nix
fmf.services.llama-cpp.runtimes = {
  prism = {package = pkgs.fmf.llama-cpp-prism; port = 18082;};
  mainline = {package = pkgs.fmf.llama-cpp-mainline; port = 18083;};
};
```

A host without a runtime does not get that runtime's models (the default catalog is filtered), so existing hosts are
unchanged. Each GGUF package declares the runtime that can read it (`passthru.runtime`) and the module refuses a
different assignment: the PTQ1_0 file is never started on a build that cannot read it. Clients reach a runtime at
`/<name>/v1` on the same host with the same key; Campground's Traefik strips the prefix, and fmf's OpenCode module adds
one provider per runtime (`llama-cpp-prism`, `llama-cpp-mainline`) next to `llama-cpp`.

### Why a fork, and why a second upstream

* **PrismML fork (`pkgs.fmf.llama-cpp-prism`, commit `d7b2896`, release `prism-b12128-d7b2896`).** `PTQ1_0` and `PQ2_0` are
  quantization types the fork adds; stock llama.cpp rejects them as unknown, so there is no upstream setting that reads
  them. The fork also has the ternary hybrid-attention CUDA kernels, and the model card measures PTQ1_0 as the faster
  decode on Ada cards (RTX 4090 91.1 tok/s against 81.2 for PQ2_0; PQ2_0 is faster at prompt processing). The weights
  are stored in a Hadamard-rotated basis and the file declares the rotation, so a runtime must apply the matching
  activation transform or refuse; the fork does. Built against nixpkgs' CUDA 12, not 13.3 (the model's KNOWN_ISSUES.md
  lists CUDA 13.3 crashes) and for Ada only (`89-real`; the fork's CMake can fail with an empty architecture list).
  Bonsai-demo itself pins the older `prism-b10777-e3de715`; this pin is newer on purpose.
* **Second upstream build (`pkgs.fmf.llama-cpp-mainline`, `b12651`).** `Q2_0` needs the Hadamard activation runtime that
  upstream has from b11556 on: **an older build loads `Q2_0` without any warning and produces garbage**, so nixpkgs'
  b9190 must not serve it. Inkling 2 (`inkling2_loop`) is upstream after b12600; do not go below b12619.
* Neither replaces `pkgs.llama-cpp`. Neither embeds the web UI (API servers only).

### Bonsai (ternary)

`ternary-bonsai-2-27b` is the preferred entry: PTQ1_0 on the fork. `ternary-bonsai-2-27b-q2_0` is the stock-llama.cpp
fallback and the reference for comparing the packings. Sampling is the model card's thinking mode (`temp 1.0`, `top-p
0.95`, `top-k 20`, `min-p 0.05`, no penalties); `flash-attn on`, every layer offloaded, `cache-ram 24576` (the vendor's
workaround for one conversation re-processing its prompt). The model reasons before it answers and the reasoning counts
against the output limit, so its output limit is 8192, not 2048 (vendor guidance is 16384 or more for hard problems; send
`reasoning_effort: "medium"` to shorten it, never `"high"`, which the template rejects with HTTP 500). Context starts at
32768, not the catalog's 64K. The vendor lists malformed tool calls as an open model limitation and HTTP 500 for a tool
call with empty or non-JSON `arguments` (send `"{}"`).

### Inkling 2 Mini (sparse MoE, looped)

Only the **Unsloth UD-IQ3_XXS** file is in the catalog, with Unsloth's `mmproj-F16.gguf` (images). Reasons, from the
upstream tracker as of 2026-11-23:

* **Partial GPU offload corrupts output.** In upstream llama.cpp, putting the experts of any looped block (6 to 17) on
  the CPU (`--cpu-moe`, `--n-cpu-moe`, `-ot`, or `fit` doing it) gives NaN or garbage logits, on CUDA and Vulkan
  (ggml-org/llama.cpp#32710); all on the GPU, or all on the CPU, are the two states that work. So the preset sets
  `fit = off` and offloads every layer: if it does not fit, the load fails loudly rather than moving experts to the CPU.
* **Long prompts.** Prompts past roughly 96 tokens produced an all-`?` reply from the first token and a server that stays
  broken until restarted (#32778); a reporter on the same GPU found `--no-op-offload` cured it, and the preset sets it
  (it has no effect with every weight on the GPU). **Still open upstream; not reproduced or ruled out here (no GPU on
  the host that built this).** Treat a short greeting test as meaningless: see the checks below.
* **Quant choice.** UD-IQ3_XXS is 11.66 GB; UD-Q3_K_XL (13.63 GB, packaged as
  `pkgs.fmf.llama-model-inkling-2-mini-ud-q3-k-xl`, not listed) plus the projector, KV and CUDA buffers leaves nothing
  on a 16 GB card shared with a desktop. ggml-org's own GGUFs start at 17.6 GB (IQ4_NL). Unsloth's repository root holds
  the files that load on mainline llama.cpp (identical to its `Mainline_Support/` copies); `Old_Support/` is for
  Unsloth's own fork.
* **Settings.** Sampling `temp 1.0, top-p 1.0, top-k 0, min-p 0.0` (Unsloth). The chat template is the GGUF's own (jinja);
  the looped layers need no flag, since the loop count is in the GGUF. Context starts at 32768 and is unmeasured.
* Not used: Unsloth's DSpark drafter and its `b12649-mix` fork build (speed only, and the fork is not upstream).

### Checking Inkling on the GPU before trusting it

A greeting proves nothing. Through the front door clients use, with the llama.cpp API key in `$KEY`:

(This script has not been run against a model: it is the procedure, not a result.)

```bash
export U=https://llama.lan.aicampground.com/mainline   # the backend itself only accepts the LAN proxy and loopback
# 1. several turns, and a prompt well past 96 tokens, then a ~6000-token one; every reply must be words, not '?'
python3 - <<'PY'
import json, os, urllib.request
def ask(messages):
    r = urllib.request.Request(os.environ["U"] + "/v1/chat/completions", json.dumps({"model": "inkling-2-mini", "messages": messages, "max_tokens": 512}).encode(),
        {"Authorization": "Bearer " + os.environ["KEY"], "Content-Type": "application/json"})
    d = json.load(urllib.request.urlopen(r, timeout=900)); m = d["choices"][0]["message"]
    print(d["usage"], (m.get("content") or "")[:120].replace("\n", " "))
    assert (m.get("content") or m.get("reasoning_content") or "").strip("? \n"), "empty or all-?"
    return m
h = [{"role": "user", "content": "Summarise this: " + "The quick brown fox jumps over the lazy dog. " * 12}]
for follow in ["Now in one word.", "What was the animal?", "Repeat my first message's last sentence.", "x " * 6000 + " Roughly how many x's was that?"]:
    h.append(dict(ask(h), role="assistant")); h.append({"role": "user", "content": follow})
ask(h)
PY
journalctl -u llama-cpp-mainline -n 80 | grep -i 'nan\|error\|failed'   # nothing expected
nvidia-smi --query-gpu=memory.used,memory.total --format=csv            # while loaded
```

Also send an image and a tool-calling request, and repeat after `systemctl restart llama-cpp-mainline`.

### GPU limits, memory and measurements

**Nothing here has been measured on the RTX 4070 Ti SUPER.** The host that wrote this change has no GPU and could not
reach sledge's, so what is verified is configuration (Nix evaluation, unit wiring, every preset key parsed by the real
CPU builds of both new runtimes with fake weights, client provider output) and not inference. The context sizes (32K)
are starting values, not measured fits. Model size is not VRAM use. Measure, on sledge, each of these at 4K, 16K and 32K
and record them here: load time (journal), peak VRAM (`nvidia-smi` while loaded), RAM, `llama-bench -m <gguf> -ngl 99 -fa 1
-p 512 -n 128 -d 0,4096,16384,32768` per build (PTQ1_0 on the fork against Q2_0 on mainline), and the Inkling long-prompt
check above for UD-IQ3_XXS and, if you want to try it with the desktop off the GPU, UD-Q3_K_XL. The routers do not
coordinate: with a model resident in `llama-cpp` (up to 300 s after use), `llama-cpp-mainline` may be unable to load
Inkling, which must have the whole model on the GPU; it then fails to load and answers an error, it does not evict the
other. Strata and the desktop share the same card (see `minFreeVramMiB` there).
