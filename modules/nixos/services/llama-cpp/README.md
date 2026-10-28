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
| `qwen36-35b-a3b-ud-iq3-s` | 13,676,723,168 | 8192 |
| `qwen3-coder-30b-a3b-ud-q3-k-xl` | 13,806,312,608 | 4096 |
| `devstral-small-2-24b-q4-k-m` | 14,334,446,752 | 2048 |

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
`gpt-oss-20b`, `qwen3.6-35b-a3b`, `qwen3-coder-30b-a3b`, and `devstral-small-2`.
`--models-max 1` limits loaded models, `--parallel 1` limits request slots, and
`--offline` prevents runtime model downloads. Presets use embedded Jinja chat
templates, explicit contexts, 256/128 batch/microbatch sizes, automatic GPU
offload/Flash Attention, a 2048 MiB fit margin, and five-minute idle sleep.
Switching has cold-load latency and may wait for a busy model.

This uses the pinned nixpkgs llama.cpp (currently b9190), not an unverified
floating latest release. Router mode is experimental upstream. Do not expose
it on an untrusted/public network. The inference API key is also required for
inference, but `/health` is deliberately public upstream.

### GPU limits

These are conservative starting contexts, **not guaranteed 16 GiB fits**.
Model file size is not VRAM usage; KV/recurrent state, CUDA buffers, display
workloads and other applications need headroom. Automatic fit can move layers
to CPU RAM. Devstral's 2K context is especially restrictive for agent prompts.
No projector is included: Qwen3.6 and Devstral are configured for text only.
Measure on the actual GPU and validate streaming/tool calls before depending
on any model for unattended agent work.

GPT-OSS uses 32K in both server presets and OpenCode metadata. The earlier 8K
window left only about 6K usable in OpenCode 1.19.4; fixed instructions and tool
schemas can exceed that even for a short message and trigger repeated
compaction. Keep automatic compaction enabled; do not merely advertise more
context than the server allocates. Restart the server and OpenCode and use a
fresh session after changing the limit. The other three profiles retain their
small experimental windows and may also be unsuitable for full OpenCode tool
prompts until individually tuned. Increasing them on a 16 GiB GPU can require
more CPU offload. No real-model memory/performance result is implied here.

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
