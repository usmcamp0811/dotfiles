{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.agentic-ai;

  # Read API key from a runtime file path (string) WITHOUT putting it in the Nix store.
  apiKeyLine = envVar: pathStr:
    mkIf (pathStr != null) ''
      if [[ -f "${pathStr}" ]]; then
        export ${envVar}="$(<"${pathStr}")"
      fi
    '';
in {
  options.fmf.tools.agentic-ai = {
    enable = mkBoolOpt false "Enable AI coding assistants (aider, opencode, mistral-vibe, qwen-code).";

    enableAider = mkBoolOpt true "Enable aider-chat AI pair programming tool.";
    enableOpencode = mkBoolOpt true "Enable opencode AI coding agent.";
    enableMistralVibe = mkBoolOpt true "Enable mistral-vibe CLI coding agent.";
    enableQwenCode = mkBoolOpt true "Enable qwen-code CLI for Qwen3-Coder models.";

    # IMPORTANT: these are STRINGS on purpose (not types.path)
    # so they do NOT get copied into the Nix store.
    anthropicApiKeyFile =
      mkOpt (types.nullOr types.str) null
      "Runtime path (string) to file containing ANTHROPIC_API_KEY (Claude). Example: /run/secrets/anthropic_api_key";

    mistralApiKeyFile =
      mkOpt (types.nullOr types.str) null
      "Runtime path (string) to file containing MISTRAL_API_KEY. Example: /run/secrets/mistral_api_key";

    openaiApiKeyFile =
      mkOpt (types.nullOr types.str) null
      "Runtime path (string) to file containing OPENAI_API_KEY. Example: /run/secrets/openai_api_key";

    dashscopeApiKeyFile =
      mkOpt (types.nullOr types.str) null
      "Runtime path (string) to file containing DASHSCOPE_API_KEY (Qwen). Example: /run/secrets/dashscope_api_key";

    # mkStrOpt isn't in your lib.fmf helpers, so use mkOpt types.str instead.
    aiderModel =
      mkOpt types.str "claude-opus-4-5-20251101"
      "Default model for aider (e.g. claude-opus-4-5-20251101, claude-sonnet-4-5-20250929).";

    opencodeModel =
      mkOpt types.str "claude-opus-4-5-20251101"
      "Default model for opencode.";
  };

  config = mkIf cfg.enable {
    home.packages =
      (optionals cfg.enableAider [pkgs.aider-chat])
      ++ (optionals cfg.enableOpencode [pkgs.nix-unstable.opencode])
      ++ (optionals cfg.enableMistralVibe [pkgs.llm-agents.mistral-vibe])
      ++ (optionals cfg.enableQwenCode [pkgs.llm-agents.qwen-code]);

    programs.zsh.initExtra = mkMerge [
      # API keys (loaded from runtime files if provided)
      (apiKeyLine "ANTHROPIC_API_KEY" cfg.anthropicApiKeyFile)
      (apiKeyLine "MISTRAL_API_KEY" cfg.mistralApiKeyFile)
      (apiKeyLine "OPENAI_API_KEY" cfg.openaiApiKeyFile)
      (apiKeyLine "DASHSCOPE_API_KEY" cfg.dashscopeApiKeyFile)

      # Tool defaults
      (mkIf cfg.enableAider ''
        export AIDER_MODEL="${cfg.aiderModel}"
        export AIDER_PRETTY=true
        export AIDER_AUTO_COMMITS=false
      '')

      (mkIf cfg.enableOpencode ''
        export OPENCODE_MODEL="${cfg.opencodeModel}"
      '')

      # Convenience helper
      ''
        list-ai() {
          echo "Installed AI coding assistants:"
          ${optionalString cfg.enableAider ''command -v aider >/dev/null && echo "  - aider ($(aider --version 2>/dev/null | head -1 || echo installed))"''}
          ${optionalString cfg.enableOpencode ''command -v opencode >/dev/null && echo "  - opencode ($(opencode --version 2>/dev/null | head -1 || echo installed))"''}
          ${optionalString cfg.enableMistralVibe ''command -v mistral-vibe >/dev/null && echo "  - mistral-vibe"''}
          ${optionalString cfg.enableQwenCode ''command -v qwen-code >/dev/null && echo "  - qwen-code"''}
          command -v claude >/dev/null && echo "  - claude ($(claude --version 2>/dev/null | head -1 || echo installed))"
        }
      ''
    ];

    home.file.".aider.conf.yml" = mkIf cfg.enableAider {
      text = ''
        # https://aider.chat/docs/config/aider_conf.html
        model: ${cfg.aiderModel}
        pretty: true
        auto-commits: false
        show-diffs: true
        git: true
        dark-mode: true
      '';
    };

    # OpenCode config: Claude OAuth compatibility via plugin + mode prompt workaround
    xdg.configFile."opencode/opencode.json" = mkIf cfg.enableOpencode {
      text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";

        # If you run into Anthropic credential blocking in OpenCode, pin a working plugin version.
        # Otherwise you can keep "opencode-anthropic-auth" unpinned.
        plugin = [
          "opencode-anthropic-auth@0.0.9"
        ];

        # Default model when you just start opencode (keep this cloud by default)
        model = "anthropic/claude-sonnet-4-5";

        # Local Ollama provider via OpenAI-compatible adapter
        provider = {
          ollama = {
            npm = "@ai-sdk/openai-compatible";
            name = "Ollama";
            options = {
              baseURL = "http://reckless:11434/v1";

              # Some OpenAI-compatible stacks expect an apiKey field even if unused.
              # Ollama ignores it, but the client library may require it.
              apiKey = "ollama";
            };

            # These keys are OpenCode model *aliases*. The `name` is the actual Ollama model tag.
            models = {
              "qwen2.5-coder-7b" = {name = "qwen2.5-coder:7b";};
              "qwen2.5-coder-14b" = {name = "qwen2.5-coder:14b";};
              "deepseek-r1-8b" = {name = "deepseek-r1:8b";};
              "deepseek-r1-14b" = {name = "deepseek-r1:14b";};
              "mistral-small" = {name = "mistral-small3.2:latest";};
              "codellama-13b" = {name = "codellama:13b";};
            };
          };
        };

        # IMPORTANT: mode is deprecated; use agent instead.
        # You can switch agents during a session, and @mention them as well. :contentReference[oaicite:3]{index=3}
        agent = {
          # Plan: use cloud model for huge context, analysis, architecture.
          plan = {
            model = "anthropic/claude-sonnet-4-5";
            prompt = ''
              You are a senior engineer doing planning and review.
              Do not edit files.
              Output:
              1) Key observations
              2) Risks and edge cases
              3) A step-by-step plan
              4) If code changes are needed, list exact files and what will change
            '';
          };

          # Build: default to local for speed and privacy.
          build = {
            model = "ollama/qwen2.5-coder-14b";
            prompt = ''
              You are a senior engineer implementing changes.
              Make the fewest changes needed.
              Prefer production-ready code.
              If you are unsure, add a short TODO and explain what you would verify.
            '';
          };

          # Optional: a local plan agent (when you do not want cloud at all)
          "plan-local" = {
            model = "ollama/qwen2.5-coder-14b";
            prompt = ''
              Plan changes carefully.
              Do not edit files.
              Provide a clear step-by-step plan, and list the exact files to touch.
            '';
          };

          # Optional: a cloud build agent for hard cases
          "build-cloud" = {
            model = "anthropic/claude-sonnet-4-5";
            prompt = ''
              You are a senior engineer implementing changes.
              Make minimal, safe edits.
              Keep changes well-scoped and easy to review.
            '';
          };
        };
      };
    };
  };
}
