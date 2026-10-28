{...}: {
  # Keep weights lazy: Home Manager consumes only names and token limits, not
  # package paths, so remote clients never acquire the model store closures.
  llamaCppModels = {pkgs}: {
    gpt-oss-20b = {
      package = pkgs.fmf.llama-model-gpt-oss-20b-mxfp4;
      name = "GPT-OSS 20B (MXFP4)";
      # OpenCode sends instructions and tool schemas even for a short message.
      # 8K left only ~6K usable and could overflow before normal conversation.
      contextSize = 32768;
      maxOutputTokens = 2048;
    };
    "qwen3.6-35b-a3b" = {
      package = pkgs.fmf.llama-model-qwen36-35b-a3b-ud-iq3-s;
      name = "Qwen3.6 35B A3B (UD-IQ3_S)";
      contextSize = 8192;
      maxOutputTokens = 2048;
    };
    qwen3-coder-30b-a3b = {
      package = pkgs.fmf.llama-model-qwen3-coder-30b-a3b-ud-q3-k-xl;
      name = "Qwen3 Coder 30B A3B (UD-Q3_K_XL)";
      contextSize = 4096;
      maxOutputTokens = 1024;
    };
    devstral-small-2 = {
      package = pkgs.fmf.llama-model-devstral-small-2-24b-q4-k-m;
      name = "Devstral Small 2 24B (Q4_K_M)";
      contextSize = 2048;
      maxOutputTokens = 512;
    };
  };
}
