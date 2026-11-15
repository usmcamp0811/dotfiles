{...}: {
  # Models the Strata engine can serve, with the numbers OpenCode needs. Like llamaCppModels this stays lazy:
  # Home Manager reads only names and token limits, never `package`, so remote clients do not acquire weights.
  #
  # ONE Strata instance serves ONE model and answers every request with it whatever the request's "model" says
  # (serve/server.py model_for: "Other names are still served"). So an instance advertises exactly one model, the
  # one `fmf.services.strata.model` selects. The attribute name below is the id Strata itself reports in /v1/models
  # (the run config's model_name; upstream's convention is "<family name>-<size lowercased>").
  #
  # Only families Strata documents are listed: DeepSeek V4.1-Flash, Qwen3.8-Flash-Next and Qwen3.6-35B-A3B. The
  # llama.cpp catalog's other models (gpt-oss-20b, qwen3.5-9b, qwen3-coder-30b-a3b, devstral-small-2) are not in any
  # of those families and stay on llama.cpp. The llama.cpp qwen3.6 file (UD-IQ3_S, plain GGUF repo) is not a Strata
  # artifact either: see packages/models/strata-model-qwen36-35b-a3b-ud-q4-k-xl.
  strataModels = {pkgs}: {
    "qwen3.6-35b-a3b-ud-q4_k_xl" = {
      package = pkgs.fmf.strata-model-qwen36-35b-a3b-ud-q4-k-xl;
      name = "Qwen3.6 35B A3B (UD-Q4_K_XL, Strata)";
      family = "qwen36";
      # GGUF architecture; the run config's "arch".
      arch = "qwen35moe";
      # 64K matches the llama.cpp catalog so switching engines does not shrink a session. The engine keeps its KV
      # cache in VRAM at 11 * 2 * 256 * 2 * 4 = 45,056 bytes per token (setup.py kv_bytes_per_token): 2.75 GiB at 64K.
      # Strata's own default is 128K (5.5 GiB). The engine states what the sessions need before it allocates and
      # refuses a context that cannot fit, with the numbers.
      contextSize = 65536;
      maxOutputTokens = 2048;
      kvBytesPerToken = 45056;
      # Draft tokens per step for greedy requests (setup.py "mtp": measured best on the maker's R9700).
      mtp = 2;
      # Upstream's planning figures: file 22.9 GB, "RAM setup plans for" 32 GB.
      fileBytes = 22853663008;
      ramGB = 32;
    };

    # The same repository, revision, engine path and limits at 6 and 8 bits (setup.py QWEN36_FILES, docs/MODELS.md).
    # Only the file and upstream's RAM planning figure differ; the KV cache per token does not depend on the quant.
    "qwen3.6-35b-a3b-ud-q6_k_xl" = {
      package = pkgs.fmf.strata-model-qwen36-35b-a3b-ud-q6-k-xl;
      name = "Qwen3.6 35B A3B (UD-Q6_K_XL, Strata)";
      family = "qwen36";
      arch = "qwen35moe";
      contextSize = 65536;
      maxOutputTokens = 2048;
      kvBytesPerToken = 45056;
      mtp = 2;
      fileBytes = 32611711264;
      ramGB = 44;
    };
    "qwen3.6-35b-a3b-q8_0" = {
      package = pkgs.fmf.strata-model-qwen36-35b-a3b-q8-0;
      name = "Qwen3.6 35B A3B (Q8_0, Strata)";
      family = "qwen36";
      arch = "qwen35moe";
      contextSize = 65536;
      maxOutputTokens = 2048;
      kvBytesPerToken = 45056;
      mtp = 2;
      fileBytes = 37801097504;
      ramGB = 52;
    };
  };
}
