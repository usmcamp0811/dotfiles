{...}: {
  # Keep weights lazy: Home Manager consumes only names and token limits, not
  # package paths, so remote clients never acquire the model store closures.
  # Keep a uniform 64K context across the catalog so switching models does not
  # shrink an active session. This stays below each model's native context and
  # avoids the KV-cache cost of enabling their maximum advertised windows.
  llamaCppModels = {pkgs}: let
    # Ternary Bonsai 2 model card, thinking mode (Best Practices > Generation Parameters).
    bonsaiPreset = {
      flash-attn = "on";
      temp = "1.0";
      top-p = "0.95";
      top-k = 20;
      min-p = "0.05";
      presence-penalty = "0.0";
      repeat-penalty = "1.0";
      cache-ram = 24576;
    };
  in {
    gpt-oss-20b = {
      package = pkgs.fmf.llama-model-gpt-oss-20b-mxfp4;
      name = "GPT-OSS 20B (MXFP4)";
      # OpenCode sends instructions and tool schemas even for a short message.
      # 8K left only ~6K usable and could overflow before normal conversation.
      contextSize = 65536;
      maxOutputTokens = 2048;
    };
    "qwen3.6-35b-a3b" = {
      package = pkgs.fmf.llama-model-qwen36-35b-a3b-ud-iq3-s;
      name = "Qwen3.6 35B A3B (UD-IQ3_S)";
      contextSize = 65536;
      maxOutputTokens = 2048;
    };
    "qwen3.5-9b" = {
      package = pkgs.fmf.llama-model-qwen35-9b-ud-q4-k-xl;
      name = "Qwen3.5 9B (UD-Q4_K_XL)";
      contextSize = 65536;
      maxOutputTokens = 2048;
    };
    qwen3-coder-30b-a3b = {
      package = pkgs.fmf.llama-model-qwen3-coder-30b-a3b-ud-q3-k-xl;
      name = "Qwen3 Coder 30B A3B (UD-Q3_K_XL)";
      contextSize = 65536;
      maxOutputTokens = 2048;
    };
    devstral-small-2 = {
      package = pkgs.fmf.llama-model-devstral-small-2-24b-q4-k-m;
      name = "Devstral Small 2 24B (Q4_K_M)";
      contextSize = 65536;
      maxOutputTokens = 2048;
    };

    # --- Models that need a llama.cpp build other than nixpkgs' (the `runtime` field) ---
    # `runtime` names an entry of fmf.services.llama-cpp.runtimes: the model is served by that build's own
    # router, behind the same host at /<runtime>/v1. A host without that runtime does not get the model.
    # These two start at 32K, not 64K: initial values until measured on the 16 GB card (README, "GPU limits").
    # Both models reason before they answer, and the reasoning counts against the output limit, so their
    # output limit is much larger than the other models'.

    # Preferred Bonsai: PTQ1_0 (5.95 GB), only readable by the PrismML fork (pkgs.fmf.llama-cpp-prism).
    # Sampling is the model card's thinking mode. `cache-ram` is the vendor's workaround for a single
    # conversation re-processing its prompt (KNOWN_ISSUES.md); parallel is already 1.
    ternary-bonsai-2-27b = {
      package = pkgs.fmf.llama-model-ternary-bonsai-2-27b-ptq1-0;
      name = "Ternary Bonsai 2 27B (PTQ1_0, PrismML fork)";
      runtime = "prism";
      contextSize = 32768;
      maxOutputTokens = 8192;
      gpuLayers = "99";
      extraPreset = bonsaiPreset;
    };
    # Same model as stock-llama.cpp-readable Q2_0 (7.63 GB): the fallback if the fork is dropped, and the
    # reference for comparing the two packings. Requires llama.cpp b11556 or newer (mainline runtime).
    ternary-bonsai-2-27b-q2_0 = {
      package = pkgs.fmf.llama-model-ternary-bonsai-2-27b-q2-0;
      name = "Ternary Bonsai 2 27B (Q2_0, upstream)";
      runtime = "mainline";
      contextSize = 32768;
      maxOutputTokens = 8192;
      gpuLayers = "99";
      extraPreset = bonsaiPreset;
    };
    # Inkling 2 Mini, UD-IQ3_XXS (11.66 GB) + F16 vision projector (0.64 GB). It must sit completely in VRAM:
    # any CPU placement of the looped layers' experts (blocks 6 to 17) gives NaN or garbage output in upstream
    # llama.cpp (ggml-org/llama.cpp#32710, #32778). So `fit` is off and every layer is offloaded: if it does
    # not fit the load fails loudly instead of silently moving experts to the CPU. UD-Q3_K_XL (13.63 GB) is
    # packaged but not listed: it leaves no room on a card shared with the desktop. `no-op-offload` is the
    # workaround reported for the all-'?' output on long prompts; with all weights on the GPU it has no effect.
    # Sampling is Unsloth's recommendation. The chat template is the GGUF's own (jinja).
    inkling-2-mini = {
      package = pkgs.fmf.llama-model-inkling-2-mini-ud-iq3-xxs;
      mmproj = pkgs.fmf.llama-model-inkling-2-mini-mmproj-f16;
      vision = true;
      name = "Inkling 2 Mini (UD-IQ3_XXS)";
      runtime = "mainline";
      contextSize = 32768;
      maxOutputTokens = 8192;
      gpuLayers = "99";
      extraPreset = {
        fit = "off";
        no-op-offload = true;
        temp = "1.0";
        top-p = "1.0";
        top-k = 0;
        min-p = "0.0";
      };
    };
  };
}
