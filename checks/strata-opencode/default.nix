{pkgs, lib, inputs, ...}: let
  # Clients must never evaluate, let alone fetch, model weights. Make any such attempt an evaluation error.
  noWeights = pkgs.extend (final: prev: {
    fmf =
      (prev.fmf or {})
      // {
        strata-model-qwen36-35b-a3b-ud-q4-k-xl = throw "a client evaluated the Strata model weights";
        strata-model-qwen36-35b-a3b-ud-q6-k-xl = throw "a client evaluated the Strata model weights";
        strata-model-qwen36-35b-a3b-q8-0 = throw "a client evaluated the Strata model weights";
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
  # a client of the other engine paths: only the id and the limits, and no store path of any shard
  flashId = "qwen3.8-flash-next-q2_0";
  dsvId = "deepseek-v4.1-flash-2.00bpw";
  otherModel = id:
    homeWith {
      fmf.tools.agentic-ai.strata = {
        enable = true;
        apiKeyFile = "/var/lib/vault/users/tester/strata_api_key";
        model = id;
      };
    };
  badModel = homeWith {
    fmf.tools.agentic-ai.strata = {
      enable = true;
      apiKeyFile = "/run/k";
      model = "gpt-oss-20b";
    };
  };

  q8Id = "qwen3.6-35b-a3b-q8_0";
  # a client of a server that switches models: every id, each with its own limits, still nothing from the store
  multi = homeWith {
    fmf.tools.agentic-ai.strata = {
      enable = true;
      apiKeyFile = "/var/lib/vault/users/tester/strata_api_key";
      models = {
        "qwen3.6-35b-a3b-ud-q4_k_xl" = {};
        ${q8Id} = {contextSize = 32768;};
        ${flashId} = {};
        ${dsvId} = {};
      };
    };
  };
  multiBad = homeWith {
    fmf.tools.agentic-ai.strata = {
      enable = true;
      apiKeyFile = "/run/k";
      models = {"qwen3.6-35b-a3b-ud-q4_k_xl" = {}; "gpt-oss-20b" = {};};
    };
  };
  m = opencodeJson multi;

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
  # --- Qwen3.8 Flash Next and DeepSeek clients: one model under its id, the catalog's limits, nothing from the store ---
  assert builtins.attrNames (opencodeJson (otherModel flashId)).provider.strata.models == [flashId];
  assert (opencodeJson (otherModel flashId)).provider.strata.models.${flashId}.limit.context == 32768;
  assert (opencodeJson (otherModel flashId)).provider.strata.models.${flashId}.limit.input == 32768 - 2048 - 6144;
  assert builtins.attrNames (opencodeJson (otherModel dsvId)).provider.strata.models == [dsvId];
  assert (opencodeJson (otherModel dsvId)).provider.strata.models.${dsvId}.limit.context == 65536;
  assert builtins.getContext (opencodeText (otherModel flashId)) == {} && builtins.getContext (opencodeText (otherModel dsvId)) == {};
  # --- several models (a switching server): all advertised, each under its id with its own limits ---
  assert builtins.attrNames m.provider.strata.models == lib.sort lib.lessThan [id q8Id flashId dsvId];
  assert m.provider.strata.models.${id}.limit.context == 65536 && m.provider.strata.models.${flashId}.limit.context == 32768;
  assert m.provider.strata.models.${q8Id}.limit.context == 32768 && m.provider.strata.models.${q8Id}.limit.input == 32768 - 2048 - 6144;
  assert m.provider.strata.models.${dsvId}.limit.context == 65536;
  assert lib.all (x: x.tool_call == true && x.limit.output == 2048) (builtins.attrValues m.provider.strata.models);
  assert m.provider.strata.models.${q8Id}.name == "Qwen3.6 35B A3B (Q8_0, Strata)";
  assert builtins.getContext (opencodeText multi) == {};
  # without `models` it is still the one model
  assert builtins.attrNames s.provider.strata.models == [id];
  # --- everything that was there stays: Ollama, llama.cpp's five models, cloud default and agents ---
  assert s.provider ? ollama;
  assert !(s.provider ? "llama-cpp");
  assert b.provider ? ollama && b.provider ? "llama-cpp" && b.provider ? strata;
  assert builtins.attrNames b.provider."llama-cpp".models == ["devstral-small-2" "gpt-oss-20b" "qwen3-coder-30b-a3b" "qwen3.5-9b" "qwen3.6-35b-a3b"];
  assert b.provider."llama-cpp".options.apiKey == "{env:LLAMA_CPP_API_KEY}";
  assert b.provider."llama-cpp".options.baseURL == "https://llama.example.invalid/v1";
  # --- models that need another llama.cpp build: one provider per runtime, same key, <host>/<runtime>/v1 ---
  assert builtins.attrNames b.provider."llama-cpp-prism".models == ["ternary-bonsai-2-27b"];
  assert builtins.attrNames b.provider."llama-cpp-mainline".models == ["inkling-2-mini" "ternary-bonsai-2-27b-q2_0"];
  assert b.provider."llama-cpp-prism".options.baseURL == "https://llama.example.invalid/prism/v1";
  assert b.provider."llama-cpp-mainline".options.baseURL == "https://llama.example.invalid/mainline/v1";
  assert b.provider."llama-cpp-prism".options.apiKey == "{env:LLAMA_CPP_API_KEY}" && b.provider."llama-cpp-mainline".options.apiKey == "{env:LLAMA_CPP_API_KEY}";
  assert b.provider."llama-cpp-mainline".models.inkling-2-mini.limit == {context = 32768; output = 8192; input = 32768 - 8192 - 6144;};
  # only Inkling takes images, only the models that say so
  assert b.provider."llama-cpp-mainline".models.inkling-2-mini.modalities.input == ["text" "image"];
  assert b.provider."llama-cpp-prism".models.ternary-bonsai-2-27b.modalities.input == ["text"];
  assert lib.all (m: m.modalities.input == ["text"]) (builtins.attrValues b.provider."llama-cpp".models);
  # the new providers exist only when llama.cpp is enabled, and disturb no other provider
  assert !(s.provider ? "llama-cpp-prism") && !(s.provider ? "llama-cpp-mainline");
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
  assert refused multiBad;
  assert !(refused multi);
  # and a valid one is not refused
  assert !(refused strataOnly) && !(refused both);
  assert !(lib.any (a: !a.assertion && lib.hasInfix "trata" a.message) strataOnly.config.assertions);
  pkgs.runCommand "strata-opencode-regression" {} ''
    # Evaluation only: the model package was replaced by a throw, so reaching this proves a client never
    # evaluates weights.
    touch "$out"
  ''
