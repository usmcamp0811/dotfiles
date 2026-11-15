---
type: Tutorial
title: Run a bigger model with Strata on a 16 GB GPU
description: "Short walkthrough: enable the Strata server on a GPU host, point a workstation's OpenCode at it, and pick a Qwen3.6 model."
tags: [services, strata, ai, tutorial]
---

# Run a bigger model with Strata on a 16 GB GPU

llama.cpp on a 16 GB card needs the model to fit mostly in VRAM. Strata runs a
Mixture-of-Experts model that does not fit: the engine keeps the most-used
experts in VRAM and computes the rest on the CPU from a pinned RAM copy. The
model runs. It is slower than a model that fits. The [module
README](README.md) has the details and the limits.

Two machines are involved: the **GPU host** runs the server, and each
**workstation** only gets an OpenCode provider and a key. A workstation has no
engine, no CUDA and no weights.

## 1. Pick a model

One server instance serves one model. These are in the catalog (all Qwen3.6-35B-A3B,
Unsloth MTP GGUFs, 65,536-token context):

| `model` id | File size | RAM upstream plans for |
| --- | ---: | ---: |
| `qwen3.6-35b-a3b-ud-q4_k_xl` (default) | 22.9 GB | 32 GB |
| `qwen3.6-35b-a3b-ud-q6_k_xl` | 32.6 GB | 44 GB |
| `qwen3.6-35b-a3b-q8_0` | 37.8 GB | 52 GB |

Start with the default. Only it has been sized for a 16 GB card; the other two
have not been run here. Each model is a separate download from the llama.cpp one.

## 2. Create the API key (once)

```bash
vault kv put secret/campground/strata api_key="$(openssl rand -hex 32)"
```

The server refuses to start without a key. Run `vault-access` afterwards so
the `svc-strata` and per-user policies exist.

## 3. Enable the server on the GPU host

```nix
fmf.services.strata = {
  enable = true;
  host = "10.8.0.177";                 # the host's LAN address
  port = 18081;
  model = "qwen3.6-35b-a3b-ud-q4_k_xl";
  vault = { enable = true; path = "secret/campground/data/strata"; };
  lazyLoad = true;                     # start unloaded, load on first request
  idleUnloadSeconds = 300;             # give the VRAM back when idle
  memoryMax = "64G";
};
```

The engine is a CUDA build and has not been built to completion in this repo's
CI. Build it on the GPU host before you rely on it:

```bash
nix build .#strata
```

Then deploy (`sudo nixos-rebuild switch --flake .#<host>`).

## 4. Enable the client on a workstation

`fmf.services.strata-client` is a **NixOS** module. The user must already exist.

```nix
fmf.services.strata-client = {
  enable = true;
  user = "mcamp";
  baseURL = "https://strata.lan.aicampground.com/v1";   # or http://<host>:18081/v1
  model = "qwen3.6-35b-a3b-ud-q4_k_xl";                 # same as the server
  vault.path = "secret/campground/data/strata";
};
```

`model` (and `contextSize`, if you set it) must match the server. The key is
rendered to `/var/lib/vault/users/<user>/strata_api_key`.

## 5. Use it

```bash
strata-status                     # on the GPU host: /health and /v1/models
opencode --model strata/qwen3.6-35b-a3b-ud-q4_k_xl run "reply with OK"
```

`"loaded": false` in `/health` is normal with `lazyLoad` until the first
request. That request pays the cold load.

## If it does not work

| Symptom | Likely cause |
| --- | --- |
| Unit fails: "API key file … missing or unreadable" | The Vault key was not rendered. Check `systemctl status detsys-vaultAgent-strata`. |
| 401 | Wrong or missing key on the client. |
| 503 | `minFreeVramMiB` not met: llama.cpp or the desktop holds the VRAM. |
| Engine exits right after start | The context does not fit beside the experts. Lower `contextSize` on the server and the client. |
