---
type: Tutorial
title: Run bigger models with Strata on your 4070 Ti Super
description: "Step-by-step guide to setting up Strata inference and connecting it to OpenCode — larger MoE models than llama.cpp alone can fit."
resource: ./default.nix
tags: [services, strata, ai, tutorial]
---

# Run bigger models with Strata on your 4070 Ti Super

llama.cpp on a 16 GB card tops out around an 8–12 GB model. Strata lets you run
a **35B Mixture-of-Experts** model by keeping the most-used experts in your GPU
VRAM and computing the rest from pinned system RAM. You trade speed for capacity:
it works, it's slower than a fitting model on llama.cpp, but it runs something
that would otherwise be impossible.

This tutorial takes you from zero to `opencode --model strata/...` working in
under an hour (excluding the first CUDA build).

## 1. What you need

- A GPU host with an NVIDIA card (RTX 4070 Ti Super works; driver 580+) and at
  least **32 GB system RAM** (64 GB recommended). The docs target a 128 GB box,
  but 64 GB is enough.
- The model weights are a separate **~22.9 GB download** from the llama.cpp ones.

## 2. On the GPU host: enable `fmf.services.strata`

```nix
# In your NixOS config (the server node):
fmf.services.strata = {
  enable = true;
  host = "10.8.0.177";           # your host's LAN IP
  port = 18081;
  vault.enable = true;
  vault.path = "secret/campground/data/strata";   # Vault KV v2 path
  lazyLoad = true;
  idleUnloadSeconds = 300;
};
```

Then deploy:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

## 3. Create the API key (one-time)

On your Vault host, run once:

```bash
vault kv put secret/campground/strata api_key="$(openssl rand -hex 32)"
```

Then regenerate AppRole policies with `vault-access` so `svc-strata` exists on
the GPU node and the per-user read policies exist for your workstations.

## 4. Build the CUDA engine (one time, takes a while)

The engine is pinned to Strata v0.2.13.1 with CUDA 13.0. Building from source
takes a while on CPU:

```bash
nix build .#strata.engine -L
```

If the farm transfer fails (it has), build it **on the GPU host itself**:

```bash
sudo nix build /home/mcamp/code/dotfiles/#strata.engine -L
```

## 5. On your workstation: enable `fmf.services.strata-client`

```nix
# In your Home Manager config:
fmf.services.strata-client = {
  enable = true;
  user = "your-username";         # must match the Vault key path below
  baseURL = "https://strata.lan.aicampground.com/v1";  # or your host IP + port
};
```

This renders the API key to `/var/lib/vault/users/your-username/strata_api_key`
and configures OpenCode with a new provider called `strata`. Your workstation gets
**no engine, no CUDA, and no weights** — it just sends requests over the network.

## 6. Use it

Restart OpenCode, then pick the model:

```bash
opencode --model strata/qwen3.6-35b-a3b-ud-q4_k_xl run "explain quantum computing"
```

Or in an existing session, open `/models` and select `strata/qwen3.6-35b-a3b-ud-q4_k_xl`.

To check the server is running:

```bash
curl -s http://10.8.0.177:18081/health | jq
# → {"status":"ok","model":"qwen3.6-35b-a3b-ud-q4_k_xl","loaded":true,...}
```

`"loaded": false` is normal with `lazyLoad` until a request arrives — the first
request pays the cold-load cost of loading 22.9 GB of weights into VRAM + RAM.

## Quick troubleshooting

| Symptom | Fix |
|---|---|
| Unit fails: "API key file … missing" | Check `detsys-vaultAgent-strata` status; ensure the Vault secret exists and AppRole has `svc-strata`. |
| 503 on request | VRAM is busy with llama.cpp or the desktop. Wait ~300 s for idle unload, then try again. |
| 401 unauthorized | Wrong key or missing file. The client reads `/var/lib/vault/users/<user>/strata_api_key`. |
| Engine crashes at start | Context size doesn't fit beside the experts and GPU reserve. Lower `contextSize` on both server and client. |

## What you're actually running

The model is **Qwen3.6-35B-A3B** — 35 billion parameters, but only ~3B active
per token (hence "A3B"). Strata keeps the frequently-used experts in VRAM and
falls back to CPU for the rest. On a 16 GB card this is hybrid mode: it works,
but don't expect llama.cpp-on-a-larger-card speed.

Context window is 65,536 tokens. The KV cache alone takes ~2.75 GB at full
context. Compaction fires before the window overflows thanks to the built-in
headroom setting (default 6,144 tokens).
