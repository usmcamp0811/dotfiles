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
  remoteSkillsToInstall = cfg.remoteSkills;
  llamaModels = lib.fmf.llamaCppModels {inherit pkgs;};
  opencodePackage = if cfg.llamaCpp.enable then pkgs.writeShellScriptBin "opencode" ''
    # Read at process startup, not Nix evaluation; GUI and non-zsh launches work.
    # Missing Vault credentials must not break unrelated cloud providers.
    if [ -z "''${LLAMA_CPP_API_KEY:-}" ] && [ -r ${lib.escapeShellArg (if cfg.llamaCpp.apiKeyFile == null then "/dev/null" else cfg.llamaCpp.apiKeyFile)} ]; then
      export LLAMA_CPP_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg (if cfg.llamaCpp.apiKeyFile == null then "/dev/null" else cfg.llamaCpp.apiKeyFile)})"
    fi
    exec ${pkgs.llm-agents.opencode}/bin/opencode "$@"
  '' else pkgs.llm-agents.opencode;
  # OpenCode v1 Anthropic OAuth plugin. Anthropic gates model access on the
  # reported Claude Code version (e.g. "Claude Code 2.1.87 does not support this
  # model; version 2.1.280 or newer is required"). The previous plugin,
  # `op-anthropic-auth` (all releases through 0.1.4), hardcodes 2.1.87 and so
  # cannot reach newer models such as Opus 5.x. 1.8.6 reports 2.1.284 and honors
  # ANTHROPIC_CLAUDE_CODE_VERSION, so a future gate bump needs no release.
  # Keep this at the 1.x line while OpenCode is v1 (`plugin`, not `plugins`).
  opencodeAnthropicMaxFixPackage = "@ex-machina/opencode-anthropic-auth";
  opencodeAnthropicMaxFixVersion = "1.8.6";
  opencodeAnthropicMaxFixPlugin = "${opencodeAnthropicMaxFixPackage}@${opencodeAnthropicMaxFixVersion}";

  opencodeAnthropicMaxFixScript = pkgs.writeShellScript "opencode-anthropic-max-fix.sh" ''
    set -euo pipefail

    cache_dir="$HOME/.cache/opencode"
    package_json="$cache_dir/package.json"

    [[ -f "$package_json" ]] || exit 0

    PACKAGE_JSON="$package_json" PKG="${opencodeAnthropicMaxFixPackage}" VERSION="${opencodeAnthropicMaxFixVersion}" ${pkgs.nodejs}/bin/node <<'EOF'
    const fs = require("node:fs");

    const path = process.env.PACKAGE_JSON;
    const pkg = process.env.PKG;
    const version = process.env.VERSION;

    const json = JSON.parse(fs.readFileSync(path, "utf8"));
    if (!json.dependencies) json.dependencies = {};

    let changed = false;
    // Drop the superseded plugin: it hardcodes Claude Code 2.1.87.
    if (json.dependencies["op-anthropic-auth"] !== undefined) {
      delete json.dependencies["op-anthropic-auth"];
      changed = true;
    }
    if (json.dependencies[pkg] !== version) {
      json.dependencies[pkg] = version;
      changed = true;
    }
    if (changed) {
      fs.writeFileSync(path, JSON.stringify(json, null, 2) + "\n");
    }
    EOF

    installed_version="$(${pkgs.nodejs}/bin/node -e 'const fs=require("node:fs"); try { const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(p.version || ""); } catch { process.stdout.write(""); }' "$cache_dir/node_modules/${opencodeAnthropicMaxFixPackage}/package.json")"

    if [[ "$installed_version" != "${opencodeAnthropicMaxFixVersion}" ]]; then
      ${pkgs.nodejs}/bin/npm install --prefix "$cache_dir" --no-save --silent "${opencodeAnthropicMaxFixPlugin}" >/dev/null
    fi
  '';

  apiKeyLine = envVar: pathStr:
    optionalString (pathStr != null) ''
      if [[ -f "${pathStr}" ]]; then
        export ${envVar}="$(<"${pathStr}")"
      fi
    '';

  toShellList = xs: concatStringsSep " " (map escapeShellArg xs);

  optAttrs = cond: attrs:
    if cond
    then attrs
    else {};
  opencodeAnthropicAuthDeps = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode-anthropic-auth-deps";
    version = "0.1.1";
    src = inputs.opencode-anthropic-auth;
    nativeBuildInputs = [pkgs.bun];
    buildPhase = ''
      bun install --frozen-lockfile --no-progress --ignore-scripts --no-cache
      rm -rf node_modules/.cache
    '';
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-KuJgqiHPGvj7matYLcdLzNHLGHcRdj3A+jUBJHmRFrs=";
  };

  opencodeAnthropicAuth = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode-anthropic-auth";
    version = "0.1.1";
    src = inputs.opencode-anthropic-auth;
    nativeBuildInputs = [pkgs.bun pkgs.nodejs pkgs.coreutils];
    configurePhase = ''
      cp -r ${opencodeAnthropicAuthDeps}/node_modules .
    '';
    buildPhase = ''
      patchShebangs node_modules
      ${pkgs.nodejs}/bin/node node_modules/typescript/bin/tsc -p tsconfig.build.json
    '';
    installPhase = ''
      mkdir -p $out
      cp -r dist package.json node_modules $out/
    '';
  };
in {
  options.fmf.tools.agentic-ai = {
    enable =
      mkBoolOpt false
      "Enable AI coding assistants (aider, opencode, mistral-vibe, qwen-code).";

    enableAider = mkBoolOpt true "Enable aider-chat AI pair programming tool.";
    enableOpencode = mkBoolOpt true "Enable opencode AI coding agent.";
    llamaCpp = {
      enable = lib.mkEnableOption "authenticated remote llama.cpp provider in OpenCode";
      baseURL = mkOption {
        type = types.str;
        default = "http://127.0.0.1:18080/v1";
        description = "OpenAI-compatible llama.cpp API base URL. Use HTTPS across the network.";
      };
      apiKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "User-readable runtime API-key path, outside the Nix store.";
      };
      compactionHeadroom = mkOption {
        type = types.ints.unsigned;
        default = 6144;
        description = ''
          Tokens kept free below each model's window when OpenCode decides to compact. OpenCode
          compacts at context minus max output (30720 of 32768 here), but compaction sends the whole
          history plus a summary prompt, so it has to fit in the window too. This sets limit.input to
          context minus max output minus this headroom, so compaction starts early enough to succeed.
        '';
      };
      toolOutput = {
        maxLines = mkOption {
          type = types.ints.positive;
          default = 500;
          description = ''
            Lines of one tool result OpenCode keeps before truncating it to disk (its default is 2000).
            A single large read or grep can add ~15K tokens at once; against a 32K local window that
            overflows the server before the agent can compact, and compaction then overflows too.
          '';
        };
        maxBytes = mkOption {
          type = types.ints.positive;
          default = 16384;
          description = "Bytes of one tool result OpenCode keeps before truncating it to disk (its default is 51200).";
        };
      };
    };
    enableMistralVibe = mkBoolOpt true "Enable mistral-vibe CLI coding agent.";
    enableQwenCode =
      mkBoolOpt true "Enable qwen-code CLI for Qwen3-Coder models.";

    enableSkills =
      mkBoolOpt true
      "Enable agent skills for OpenCode (and install configured skills).";

    enableDistill =
      mkBoolOpt false
      "Install Distill CLI (https://github.com/samuelfaj/distill).";

    opencodeSkills = mkOpt (types.attrsOf types.path) {} ''
      Local skill directories to install into ~/.config/opencode/skills/<name>/.
      Each directory should contain SKILL.md.
    '';

    remoteSkills =
      mkOpt (types.listOf types.str) []
      "Remote skills to install globally for OpenCode using skills; accepts @owner/repo/skill or a skills CLI source.";
    remoteSkillsStrict = mkBoolOpt false
      "Fail activation when a remote skill install fails; otherwise warn and continue. Remote installs are skipped during Home Manager dry runs.";

    opencodeSkillPermissionDefault =
      mkOpt (types.enum ["allow" "ask" "deny"]) "allow"
      "Default OpenCode permission for skills (applies to '*').";

    enableOpencodeAnthropicAuthPlugin =
      mkBoolOpt true
      "Enable OpenCode Anthropic OAuth plugin. Leave disabled to use ANTHROPIC_API_KEY instead.";

    anthropicApiKeyFile =
      mkOpt (types.nullOr types.str) null
      "Runtime path (string) to file containing ANTHROPIC_API_KEY.";

    mistralApiKeyFile =
      mkOpt (types.nullOr types.str) null
      "Runtime path (string) to file containing MISTRAL_API_KEY.";

    openaiApiKeyFile =
      mkOpt (types.nullOr types.str) null
      "Runtime path (string) to file containing OPENAI_API_KEY.";

    dashscopeApiKeyFile =
      mkOpt (types.nullOr types.str) null
      "Runtime path (string) to file containing DASHSCOPE_API_KEY.";

    aiderModel =
      mkOpt types.str "claude-opus-4-5-20251101" "Default model for aider.";

    opencodeModel =
      mkOpt types.str "claude-opus-4-5-20251101" "Default model for opencode.";
  };

  config = mkIf cfg.enable {
    assertions = lib.optionals cfg.llamaCpp.enable [{
      assertion = cfg.enableOpencode && cfg.llamaCpp.apiKeyFile != null
        && lib.hasPrefix "/" cfg.llamaCpp.apiKeyFile
        && !(lib.hasPrefix "/nix/store/" cfg.llamaCpp.apiKeyFile);
      message = "The llama.cpp OpenCode provider requires OpenCode and an absolute runtime apiKeyFile outside /nix/store.";
    }];
    home.packages =
      (optionals cfg.enableAider [pkgs.aider-chat])
      ++ (optionals cfg.enableOpencode [
        opencodePackage
        pkgs.backlog-md
      ])
      ++ (optionals cfg.enableMistralVibe [pkgs.llm-agents.mistral-vibe])
      ++ (optionals cfg.enableQwenCode [pkgs.llm-agents.qwen-code])
      ++ (optionals cfg.enableDistill [pkgs.fmf.distill])
      ++ (optionals
        (cfg.enableOpencode
          && cfg.enableSkills
          && remoteSkillsToInstall
          != []) [
          pkgs.llm-agents.skills
          pkgs.git
          pkgs.mcp-nixos
        ]);

    programs.zsh.initContent = concatStringsSep "\n" [
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
          ${
          optionalString cfg.enableAider ''
            command -v aider >/dev/null && echo "  - aider ($(aider --version 2>/dev/null | head -1 || echo installed))"''
        }
          ${
          optionalString cfg.enableOpencode ''
            command -v opencode >/dev/null && echo "  - opencode ($(opencode --version 2>/dev/null | head -1 || echo installed))"''
        }
          ${
          optionalString cfg.enableMistralVibe
          ''command -v mistral-vibe >/dev/null && echo "  - mistral-vibe"''
        }
          ${
          optionalString cfg.enableQwenCode
          ''command -v qwen-code >/dev/null && echo "  - qwen-code"''
        }
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

    # ONE xdg.configFile attrset, containing BOTH:
    # - local skills directories under opencode/skills/<name>
    # - opencode/opencode.json
    xdg.configFile = let
      localSkills =
        if (cfg.enableOpencode && cfg.enableSkills)
        then
          mapAttrs' (name: srcDir:
            nameValuePair "opencode/skills/${name}" {
              source = srcDir;
              recursive = true;
            })
          cfg.opencodeSkills
        else {};
    in
      localSkills
      // {
        "opencode/opencode.json" = {
          text = builtins.toJSON ({
              "$schema" = "https://opencode.ai/config.json";

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
              } // lib.optionalAttrs cfg.llamaCpp.enable {
                "llama-cpp" = {
                  npm = "@ai-sdk/openai-compatible";
                  name = "llama.cpp";
                  env = ["LLAMA_CPP_API_KEY"];
                  options = {
                    baseURL = cfg.llamaCpp.baseURL;
                    apiKey = "{env:LLAMA_CPP_API_KEY}";
                    timeout = 600000;
                  };
                  models = lib.mapAttrs (_: model: {
                    name = model.name;
                    tool_call = true;
                     limit = {
                       context = model.contextSize;
                       output = model.maxOutputTokens;
                       input = model.contextSize - model.maxOutputTokens - cfg.llamaCpp.compactionHeadroom;
                     };
                    modalities = {input = ["text"]; output = ["text"];};
                  }) llamaModels;
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
            // optAttrs cfg.enableOpencodeAnthropicAuthPlugin {
              plugin = [opencodeAnthropicMaxFixPlugin];
            }
            // optAttrs cfg.llamaCpp.enable {
              # Global in OpenCode, so it also applies to cloud models while llama.cpp is enabled.
              tool_output = {
                max_lines = cfg.llamaCpp.toolOutput.maxLines;
                max_bytes = cfg.llamaCpp.toolOutput.maxBytes;
              };
            }
            // optAttrs (cfg.enableOpencode && cfg.enableSkills) {
              permission = {
                skill = {"*" = cfg.opencodeSkillPermissionDefault;};
              };
            });
        };
      };

    home.activation.installOpencodeSkills =
      mkIf
      (cfg.enableOpencode && cfg.enableSkills && remoteSkillsToInstall != [])
      (inputs.home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        echo "Installing OpenCode skills (skills)..."
        export PATH="${pkgs.llm-agents.skills}/bin:${pkgs.git}/bin:$PATH"

        ${import ./install-skills.nix {
          inherit lib;
          sources = remoteSkillsToInstall;
          command = "${pkgs.llm-agents.skills}/bin/skills";
          strict = cfg.remoteSkillsStrict;
        }}
      '');

    home.activation.opencodeAnthropicMaxFix =
      mkIf (cfg.enableOpencode && cfg.enableOpencodeAnthropicAuthPlugin)
      (inputs.home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        "${opencodeAnthropicMaxFixScript}"
      '');

    systemd.user.services.opencode-anthropic-max-fix = mkIf (cfg.enableOpencode && cfg.enableOpencodeAnthropicAuthPlugin) {
      Unit = {Description = "Pin OpenCode Anthropic auth plugin version";};
      Service = {
        Type = "oneshot";
        ExecStart = "${opencodeAnthropicMaxFixScript}";
      };
    };

    systemd.user.paths.opencode-anthropic-max-fix = mkIf (cfg.enableOpencode && cfg.enableOpencodeAnthropicAuthPlugin) {
      Unit = {
        Description = "Watch OpenCode package.json for Anthropic fix";
      };
      Path = {
        PathModified = "%h/.cache/opencode/package.json";
        Unit = "opencode-anthropic-max-fix.service";
      };
      Install = {WantedBy = ["default.target"];};
    };
  };
}
