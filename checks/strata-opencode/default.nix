{pkgs, lib, inputs, ...}: let
  # Clients must never evaluate, let alone fetch, model weights. Make any such attempt an evaluation error.
  noWeights = pkgs.extend (final: prev: {
    fmf =
      (prev.fmf or {})
      // {
        strata-model-qwen36-35b-a3b-ud-q4-k-xl = throw "a client evaluated the Strata model weights";
      };
  });

  homeWith = extra:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = noWeights;
      # the fmf-aware lib: the module reads lib.fmf (home-manager would otherwise hand it its own lib)
      inherit lib;
      # Modules take `lib` from specialArgs (as in the NixOS checks). It must carry both lib.fmf (this repo's helpers)
      # and lib.hm (home-manager's), because specialArgs replaces the lib home-manager would have extended itself.
      extraSpecialArgs = {
        inherit inputs;
        lib = lib.extend (_: _: {
          hm = inputs.home-manager.lib.hm;
          # this flake's own helpers (mkOpt, enabled, strataModels, ...): its `lib` output is the fmf namespace itself
          fmf = inputs.self.lib;
        });
      };
      modules = [
        ../../modules/home/tools/agentic-ai
        {
          home = {
            username = "tester";
            homeDirectory = "/home/tester";
            stateVersion = "26.05";
          };
          fmf.tools.agentic-ai = {
            enable = true;
            enableAider = false;
            enableMistralVibe = false;
            enableQwenCode = false;
            enableSkills = false;
          };
        }
        extra
      ];
    };

  opencodeJson = hm: builtins.fromJSON hm.config.xdg.configFile."opencode/opencode.json".text;
  opencodeText = hm: hm.config.xdg.configFile."opencode/opencode.json".text;

  none = homeWith {};
  strataOnly = homeWith {
    fmf.tools.agentic-ai.strata = {
      enable = true;
      baseURL = "https://strata.example.invalid/v1";
      apiKeyFile = "/var/lib/vault/users/tester/strata_api_key";
    };
  };
  both = homeWith {
    fmf.tools.agentic-ai = {
      llamaCpp = {
        enable = true;
        baseURL = "https://llama.example.invalid/v1";
        apiKeyFile = "/var/lib/vault/users/tester/llama_api_key";
      };
      strata = {
        enable = true;
        baseURL = "https://strata.example.invalid/v1";
        apiKeyFile = "/var/lib/vault/users/tester/strata_api_key";
        contextSize = 32768;
      };
    };
  };
  storeKey = homeWith {
    fmf.tools.agentic-ai.strata = {
      enable = true;
      apiKeyFile = "/nix/store/aaaa-key";
    };
  };
  badModel = homeWith {
    fmf.tools.agentic-ai.strata = {
      enable = true;
      apiKeyFile = "/run/k";
      model = "gpt-oss-20b";
    };
  };

  base = opencodeJson none;
  s = opencodeJson strataOnly;
  b = opencodeJson both;
  id = "qwen3.6-35b-a3b-ud-q4_k_xl";
  # Home Manager throws "Failed assertions" when its assertions are evaluated for an invalid configuration (unlike
  # NixOS, which returns the list), so a refusal is an evaluation that does not succeed.
  refused = hm: !(builtins.tryEval (builtins.deepSeq hm.config.assertions true)).success;
in
  # --- off by default: nothing about Strata appears ---
  assert !(base.provider ? strata);
  assert !(lib.hasInfix "STRATA" (opencodeText none));
  # --- Strata on: one provider, the OpenAI-compatible adapter, the key from the environment ---
  assert s.provider.strata.npm == "@ai-sdk/openai-compatible";
  assert s.provider.strata.options.baseURL == "https://strata.example.invalid/v1";
  assert s.provider.strata.options.apiKey == "{env:STRATA_API_KEY}";
  assert s.provider.strata.env == ["STRATA_API_KEY"];
  # exactly one model, under the id the server reports (the instance ignores whatever id a client sends)
  assert builtins.attrNames s.provider.strata.models == [id];
  assert s.provider.strata.models.${id}.tool_call == true;
  assert s.provider.strata.models.${id}.limit.context == 65536;
  assert s.provider.strata.models.${id}.limit.output == 2048;
  # compaction headroom: input = context - output - headroom, as for llama.cpp
  assert s.provider.strata.models.${id}.limit.input == 65536 - 2048 - 6144;
  # a smaller advertised window follows the contextSize option
  assert b.provider.strata.models.${id}.limit.context == 32768;
  assert b.provider.strata.models.${id}.limit.input == 32768 - 2048 - 6144;
  # --- everything that was there stays: Ollama, llama.cpp's five models, cloud default and agents ---
  assert s.provider ? ollama;
  assert !(s.provider ? "llama-cpp");
  assert b.provider ? ollama && b.provider ? "llama-cpp" && b.provider ? strata;
  assert builtins.attrNames b.provider."llama-cpp".models == ["devstral-small-2" "gpt-oss-20b" "qwen3-coder-30b-a3b" "qwen3.5-9b" "qwen3.6-35b-a3b"];
  assert b.provider."llama-cpp".options.apiKey == "{env:LLAMA_CPP_API_KEY}";
  assert s.model == base.model && b.model == base.model;
  assert s.agent == base.agent && b.agent == base.agent;
  assert (base.plugin or null) == (s.plugin or null);
  # the tool-output cap is global in OpenCode and now applies when either local provider is on
  assert s.tool_output == b.tool_output && !(base ? tool_output);
  # --- no weights or other store paths are baked into the config ---
  assert builtins.getContext (opencodeText strataOnly) == {};
  assert !(lib.hasInfix "/nix/store" (opencodeText both));
  # --- refusals ---
  assert refused storeKey;
  assert refused badModel;
  # and a valid one is not refused
  assert !(refused strataOnly) && !(refused both);
  assert !(lib.any (a: !a.assertion && lib.hasInfix "trata" a.message) strataOnly.config.assertions);
  pkgs.runCommand "strata-opencode-regression" {} ''
    # Evaluation only: the model package was replaced by a throw, so reaching this proves a client never
    # evaluates weights.
    touch "$out"
  ''
