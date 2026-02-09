# homeManagerModules/development/ai-coding.nix
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

  system = pkgs.stdenv.hostPlatform.system;

  llmAgentsPkgs =
    inputs.llm-agents.packages.${system} or (throw "inputs.llm-agents.packages.${system} is missing");

  mistral-vibe = llmAgentsPkgs.mistral-vibe;
  qwen-code = llmAgentsPkgs.qwen-code;

  # Use unstable nixpkgs for opencode to get newer versions (streaming fixes, etc.)
  pkgsUnstable = import inputs.unstable-nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  apiKeyLine = envVar: pathOpt:
    mkIf (pathOpt != null) ''
      if [[ -f "${pathOpt}" ]]; then
        export ${envVar}="$(<"${pathOpt}")"
      fi
    '';
in {
  options.fmf.tools.agentic-ai = {
    enable = mkBoolOpt false "Enable AI coding assistants (aider, opencode, mistral-vibe, qwen-code).";

    enableAider = mkBoolOpt true "Enable aider-chat AI pair programming tool.";
    enableOpencode = mkBoolOpt true "Enable opencode AI coding agent.";
    enableMistralVibe = mkBoolOpt true "Enable mistral-vibe CLI coding agent.";
    enableQwenCode = mkBoolOpt true "Enable qwen-code CLI for Qwen3-Coder models.";

    # API key file inputs (prefer secrets via sops/agenix/vault-mounted files)
    anthropicApiKeyFile =
      mkOpt (types.nullOr types.path) null
      "Path to file containing ANTHROPIC_API_KEY (Claude).";
    mistralApiKeyFile =
      mkOpt (types.nullOr types.path) null
      "Path to file containing MISTRAL_API_KEY.";
    openaiApiKeyFile =
      mkOpt (types.nullOr types.path) null
      "Path to file containing OPENAI_API_KEY.";
    dashscopeApiKeyFile =
      mkOpt (types.nullOr types.path) null
      "Path to file containing DASHSCOPE_API_KEY (Qwen).";

    aiderModel =
      mkStrOpt "claude-opus-4-5-20251101"
      "Default model for aider (e.g. claude-opus-4-5-20251101, claude-sonnet-4-5-20250929).";

    opencodeModel =
      mkStrOpt "claude-opus-4-5-20251101"
      "Default model for opencode.";
  };

  config = mkIf cfg.enable {
    home.packages =
      (optionals cfg.enableAider [pkgs.aider-chat])
      ++ (optionals cfg.enableOpencode [pkgsUnstable.opencode])
      ++ (optionals cfg.enableMistralVibe [mistral-vibe])
      ++ (optionals cfg.enableQwenCode [qwen-code]);

    programs.zsh.initExtra = mkMerge [
      # API keys (loaded from files if provided)
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
        plugin = ["opencode-anthropic-auth"];
        mode = {
          build.prompt = "You are Claude Code, Anthropic's official CLI for Claude.";
          plan.prompt = "You are Claude Code, Anthropic's official CLI for Claude.";
        };
      };
    };
  };
}
