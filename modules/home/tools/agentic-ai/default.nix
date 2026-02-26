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
    optionalString (pathStr != null) ''
      if [[ -f "${pathStr}" ]]; then
        export ${envVar}="$(<"${pathStr}")"
      fi
    '';

  # Helper: convert list values to a list of strings safely for shell loops.
  toShellList = xs: concatStringsSep " " (map escapeShellArg xs);

  # Helper: conditionally add attrs (pure expression, safe inside toJSON merges etc.)
  optAttrs = cond: attrs:
    if cond
    then attrs
    else {};
in {
  options.fmf.tools.agentic-ai = {
    enable = mkBoolOpt false "Enable AI coding assistants (aider, opencode, mistral-vibe, qwen-code).";

    enableAider = mkBoolOpt true "Enable aider-chat AI pair programming tool.";
    enableOpencode = mkBoolOpt true "Enable opencode AI coding agent.";
    enableMistralVibe = mkBoolOpt true "Enable mistral-vibe CLI coding agent.";
    enableQwenCode = mkBoolOpt true "Enable qwen-code CLI for Qwen3-Coder models.";

    # Skills
    enableSkills = mkBoolOpt true "Enable agent skills for OpenCode (and install configured skills).";

    # Local/vendored skills: attrset of name -> path-to-skill-directory
    # Directory must contain SKILL.md (and optionally other files).
    opencodeSkills =
      mkOpt (types.attrsOf types.path) {}
      ''
        Local skill directories to install into ~/.config/opencode/skills/<name>/.
        Each directory should contain SKILL.md.
      '';

    # Remote skills installed via skills-installer (identifiers like @owner/repo/skill-name)
    remoteSkills =
      mkOpt (types.listOf types.str) []
      "Remote skills to install using skills-installer (for the opencode client).";

    # OpenCode permission default for skills:
    opencodeSkillPermissionDefault =
      mkOpt (types.enum ["allow" "ask" "deny"]) "allow"
      "Default OpenCode permission for skills (applies to '*').";

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
      ++ (optionals cfg.enableOpencode [pkgs.llm-agents.opencode])
      ++ (optionals cfg.enableMistralVibe [pkgs.llm-agents.mistral-vibe])
      ++ (optionals cfg.enableQwenCode [pkgs.llm-agents.qwen-code])
      ++ (optionals (cfg.enableOpencode && cfg.enableSkills && cfg.remoteSkills != []) [
        pkgs.llm-agents.skills-installer
        pkgs.git
      ]);

    # zsh init: build as one string (no mkMerge)
    programs.zsh.initExtra = concatStringsSep "\n" [
      (apiKeyLine "ANTHROPIC_API_KEY" cfg.anthropicApiKeyFile)
      (apiKeyLine "MISTRAL_API_KEY" cfg.mistralApiKeyFile)
      (apiKeyLine "OPENAI_API_KEY" cfg.openaiApiKeyFile)
      (apiKeyLine "DASHSCOPE_API_KEY" cfg.dashscopeApiKeyFile)

      (optionalString cfg.enableAider ''
        export AIDER_MODEL="${cfg.aiderModel}"
        export AIDER_PRETTY=true
        export AIDER_AUTO_COMMITS=false
      '')

      (optionalString cfg.enableOpencode ''
        export OPENCODE_MODEL="${cfg.opencodeModel}"
      '')

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

    # Install local/vendored skills into OpenCode's global skills directory:
    xdg.configFile = mkIf (cfg.enableOpencode && cfg.enableSkills) (
      mapAttrs'
      (name: srcDir:
        nameValuePair "opencode/skills/${name}" {
          source = srcDir;
          recursive = true;
        })
      cfg.opencodeSkills
    );

    # Install remote skills at activation time via skills-installer (client=opencode).
    home.activation.installOpencodeSkills = mkIf (cfg.enableOpencode && cfg.enableSkills && cfg.remoteSkills != []) (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        echo "Installing OpenCode skills (skills-installer)..."
        export PATH="${pkgs.llm-agents.skills-installer}/bin:${pkgs.git}/bin:$PATH"

        for skill in ${toShellList cfg.remoteSkills}; do
          echo "  - $skill"
          skills-installer install --client opencode "$skill"
        done
      ''
    );

    # OpenCode config
    xdg.configFile."opencode/opencode.json" = {
      text = builtins.toJSON (
        {
          "$schema" = "https://opencode.ai/config.json";

          plugin = ["opencode-anthropic-auth"];

          # Default cloud fallback (used when agent doesn't override)
          model = "anthropic/claude-sonnet-4-5";

          provider = {
            ollama = {
              npm = "@ai-sdk/openai-compatible";
              name = "Ollama";
              options = {
                baseURL = "http://reckless:11434/v1";
                apiKey = "ollama";
                compatibility = "strict";
              };

              models = {
                "qwen2.5-coder:7b" = {
                  name = "qwen2.5-coder:7b";
                  tools = true;
                  options = {
                    num_ctx = 16384;
                    temperature = 0.2;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 2048;
                    stop = ["</s>"];
                  };
                };

                "qwen2.5-coder:14b" = {
                  name = "qwen2.5-coder:14b";
                  tools = true;
                  options = {
                    num_ctx = 16384;
                    temperature = 0.2;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 2048;
                    stop = ["</s>"];
                  };
                };

                "deepseek-r1:8b" = {
                  name = "deepseek-r1:8b";
                  tools = false;
                  options = {
                    num_ctx = 16384;
                    temperature = 0.3;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 1536;
                    stop = ["</s>"];
                  };
                };

                "deepseek-r1:14b" = {
                  name = "deepseek-r1:14b";
                  tools = false;
                  options = {
                    num_ctx = 16384;
                    temperature = 0.3;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 1536;
                    stop = ["</s>"];
                  };
                };

                "mistral-small3.2:latest" = {
                  name = "mistral-small3.2:latest";
                  tools = false;
                  options = {
                    num_ctx = 16384;
                    temperature = 0.4;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 1536;
                    stop = ["</s>"];
                  };
                };

                "codellama:13b" = {
                  name = "codellama:13b";
                  tools = false;
                  options = {
                    num_ctx = 8192;
                    temperature = 0.25;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 1536;
                    stop = ["</s>"];
                  };
                };

                "qwen3:8b" = {
                  name = "qwen3:8b";
                  tools = true;
                  options = {
                    num_ctx = 8192;
                    temperature = 0.25;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 2048;
                    stop = ["</s>"];
                  };
                };

                "qwen3:8b-16k" = {
                  name = "qwen3:8b-16k";
                  tools = true;
                  options = {
                    num_ctx = 16384;
                    temperature = 0.25;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 2048;
                    stop = ["</s>"];
                  };
                };

                "gpt-oss:20b" = {
                  name = "gpt-oss:20b";
                  tools = true;
                  options = {
                    num_ctx = 16384;
                    temperature = 0.25;
                    top_p = 0.9;
                    repeat_penalty = 1.1;
                    num_predict = 2048;
                    stop = ["</s>"];
                  };
                };
              };
            };
          };

          agent = let
            base_rules = ''
              You are an AI coding agent working in a real repository.
              Do not invent files, commands, outputs, or CI results.
              If you cannot verify something, say so and propose a concrete check.
              Prefer NixOS-compatible instructions for system tasks.
              When editing code, provide complete copy-pasteable code blocks (no git diffs).
            '';

            planner_rules = ''
              ${base_rules}
              Your job: produce a small, executable plan.
              Output: numbered steps + verification commands.
              Do not write code unless explicitly asked.
            '';

            builder_rules = ''
              ${base_rules}
              Your job: implement the requested change with minimal scope.
              Keep changes small and focused. Avoid refactors unless required.
              Include how to run/verify locally.
            '';

            coder_rules = ''
              ${base_rules}
              Your job: write correct, idiomatic code.
              Prefer correctness over cleverness. Include edge cases and tests when relevant.
            '';
          in {
            codex = {
              model = "openai/codex-5-3";
              prompt = coder_rules;
            };

            plan = {
              model = "anthropic/claude-sonnet-4-5";
              prompt = planner_rules;
            };

            build = {
              model = "anthropic/claude-sonnet-4-5";
              prompt = builder_rules;
            };

            "build-local" = {
              model = "qwen2.5-coder:14b";
              prompt = builder_rules;
            };

            "plan-local" = {
              model = "deepseek-r1:14b";
              prompt = planner_rules;
            };

            "explainer-local" = {
              model = "qwen3:8b";
              prompt = ''
                ${base_rules}
                Your job: explain concepts concisely with practical examples.
                Prefer short sections and actionable guidance.
              '';
            };
          };
        }
        // optAttrs (cfg.enableOpencode && cfg.enableSkills) {
          permission = {
            skill = {
              "*" = cfg.opencodeSkillPermissionDefault;
            };
          };
        }
      );
    };
  };
}
