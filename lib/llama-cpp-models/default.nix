{...}: {
  # Keep weights lazy: Home Manager consumes only names and token limits, not
  # package paths, so remote clients never acquire the model store closures.
  # Keep a uniform 64K context across the catalog so switching models does not
  # shrink an active session. This stays below each model's native context and
  # avoids the KV-cache cost of enabling their maximum advertised windows.
  llamaCppModels = {pkgs}: {
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
  };
}
