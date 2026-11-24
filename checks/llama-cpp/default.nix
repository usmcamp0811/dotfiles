{pkgs, ...}: let
  # Deliberately invalid, tiny files: router startup/listing must not load them.
  fakeModel = pkgs.writeText "test-model.gguf" "not-real-model-weights";
  catalog = (import ../../lib/llama-cpp-models {}).llamaCppModels {inherit pkgs;};
  # Exercise every real ID/limit, substituting tiny files for weights only (and for the projector, so
  # nothing here realizes a multi-GB GGUF).
  testModels = pkgs.lib.mapAttrs (_: model: model // {
    package = fakeModel;
  } // pkgs.lib.optionalAttrs (model ? mmproj) {mmproj = fakeModel;}) catalog;
  # Check advertised context budgets without realizing any GGUF derivations.
  expectedContexts = {
    gpt-oss-20b = 65536;
    "qwen3.6-35b-a3b" = 65536;
    "qwen3.5-9b" = 65536;
    qwen3-coder-30b-a3b = 65536;
    devstral-small-2 = 65536;
    ternary-bonsai-2-27b = 32768;
    ternary-bonsai-2-27b-q2_0 = 32768;
    inkling-2-mini = 32768;
  };
  mainModels = ["gpt-oss-20b" "qwen3.6-35b-a3b" "qwen3.5-9b" "qwen3-coder-30b-a3b" "devstral-small-2"];
  # CPU builds of the two extra runtimes: the real binaries, so every preset key is parsed by the build
  # that will serve it.
  prism = pkgs.fmf.llama-cpp-prism.override {cudaSupport = false;};
  mainline = pkgs.fmf.llama-cpp-mainline.override {cudaSupport = false;};
  runtimeModels = {
    prism = {port = 18082; models = ["ternary-bonsai-2-27b"];};
    mainline = {port = 18083; models = ["inkling-2-mini" "ternary-bonsai-2-27b-q2_0"];};
  };
  # The catalog says which build each model needs; a GGUF only one build reads must not drift to another.
  expectedRuntime = {
    ternary-bonsai-2-27b = "prism";
    ternary-bonsai-2-27b-q2_0 = "mainline";
    inkling-2-mini = "mainline";
  };
in assert pkgs.lib.mapAttrs (_: model: model.contextSize) catalog == expectedContexts;
assert pkgs.lib.all (id: catalog.${id}.maxOutputTokens == 2048) mainModels;
assert pkgs.lib.all (id: (catalog.${id}.runtime or null) == null) mainModels;
assert pkgs.lib.mapAttrs (_: model: model.runtime) (pkgs.lib.filterAttrs (_: model: model ? runtime) catalog) == expectedRuntime;
# Packages say what they need: the pinned weights and the catalog must agree.
assert pkgs.lib.all (id: catalog.${id}.package.passthru.runtime == expectedRuntime.${id}) (builtins.attrNames expectedRuntime);
# Inkling must never be partly placed on the CPU (ggml-org/llama.cpp#32710) and must be offered images.
assert catalog.inkling-2-mini.extraPreset.fit == "off" && catalog.inkling-2-mini.gpuLayers == "99" && catalog.inkling-2-mini.vision;
# Bonsai: the model card's thinking-mode sampling, and a PTQ1_0 file that only the fork may serve.
assert catalog.ternary-bonsai-2-27b.extraPreset.temp == "1.0" && catalog.ternary-bonsai-2-27b.extraPreset.top-k == 20 && catalog.ternary-bonsai-2-27b.extraPreset.min-p == "0.05";
pkgs.testers.nixosTest {
  name = "llama-cpp-authenticated-router";
  nodes.server = {config, lib, ...}: {
    imports = [../../modules/nixos/services/llama-cpp];
    # This test uses a synthetic local credential and never starts Vault.
    options.fmf.services.vault-agent = lib.mkOption {
      type = lib.types.attrs;
      default = {enable = false; services = {};};
    };
    config = {
    virtualisation.memorySize = 4096;
    fmf.services.llama-cpp = {
      enable = true;
      package = pkgs.llama-cpp.override {cudaSupport = false;};
      host = "127.0.0.1";
      apiKeyFile = "/run/llama-test-key";
      router = {
        enable = true;
        models = testModels;
      };
      runtimes = {
        prism = {package = prism; port = runtimeModels.prism.port;};
        mainline = {package = mainline; port = runtimeModels.mainline.port;};
      };
    };
    systemd.services.llama-test-key = {
      requiredBy = ["llama-cpp.service" "llama-cpp-prism.service" "llama-cpp-mainline.service"];
      before = ["llama-cpp.service" "llama-cpp-prism.service" "llama-cpp-mainline.service"];
      serviceConfig.Type = "oneshot";
      # Synthetic test credential only; never a production secret.
      script = ''
        umask 077
        printf '%s\n' 'synthetic-test-key-not-a-production-secret' > /run/llama-test-key
      '';
    };
    environment.systemPackages = [pkgs.curl];
    assertions = [{
      assertion = lib.elem "--models-max" config.services.llama-cpp.extraFlags;
      message = "Router must bound loaded model count.";
    }];
    };
  };
  testScript = ''
    import json
    import shlex
    KEY = "synthetic-test-key-not-a-production-secret"
    # unit -> (port, model ids it must list). The main service keeps exactly its original five.
    servers = {
        "llama-cpp": (18080, ${builtins.toJSON mainModels}),
        "llama-cpp-prism": (${toString runtimeModels.prism.port}, ${builtins.toJSON runtimeModels.prism.models}),
        "llama-cpp-mainline": (${toString runtimeModels.mainline.port}, ${builtins.toJSON runtimeModels.mainline.models}),
    }
    server.start()
    for unit, (port, _) in servers.items():
        server.wait_for_unit(unit + ".service")
        server.wait_until_succeeds("curl -fsS http://127.0.0.1:%d/health" % port)
    for unit, (port, models) in servers.items():
        # Restarting the main unit (below) stops and restarts the runtimes with it; wait until this one is back.
        server.wait_for_unit(unit + ".service")
        server.wait_until_succeeds("curl -fsS http://127.0.0.1:%d/health" % port, timeout=60)
        with subtest(unit + ": unauthenticated inference is rejected before model loading"):
            result = server.succeed("curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d '{\"model\":\"" + models[0] + "\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}' http://127.0.0.1:" + str(port) + "/v1/chat/completions")
            assert result.strip() == "401", result
        with subtest(unit + ": authenticated model listing works without loading weights"):
            data = json.loads(server.succeed("curl -fsS -H 'Authorization: Bearer " + KEY + "' http://127.0.0.1:%d/v1/models" % port))
            assert {m["id"] for m in data["data"]} == set(models), (unit, data)
        with subtest(unit + ": every preset passes worker argument parsing and reaches the fake GGUF"):
            for model in models:
                before = int(server.succeed("journalctl -u " + unit + ".service --no-pager | grep -c 'invalid magic' || true").strip())
                payload = json.dumps({"model": model, "messages": [{"role": "user", "content": "hello"}], "max_tokens": 1})
                status, response = server.execute("curl --max-time 3 -sS -o /tmp/model-error -w '%{http_code}' -H 'Authorization: Bearer " + KEY + "' -H 'Content-Type: application/json' --data " + shlex.quote(payload) + " http://127.0.0.1:" + str(port) + "/v1/chat/completions")
                assert status == 28 or (status == 0 and response.strip() in {"500", "503"}), (model, status, response)
                # Expected failure is invalid model bytes, not an unknown preset
                # flag. This validates worker CLI options without real weights.
                # b9190 can wait indefinitely after the fake worker fails; bound
                # the negative request and reset this isolated fixture each time.
                server.wait_until_succeeds("test $(journalctl -u " + unit + ".service --no-pager | grep -c 'invalid magic') -gt " + str(before), timeout=10)
                server.succeed("systemctl kill --signal=KILL " + unit + ".service && systemctl stop " + unit + ".service && systemctl reset-failed " + unit + ".service && systemctl start " + unit + ".service")
                server.wait_until_succeeds("curl -fsS http://127.0.0.1:%d/health" % port, timeout=30)
    with subtest("each router runs its own build, with the same bounds and credentials"):
        runtimes = {
            "llama-cpp": "${pkgs.llama-cpp.override {cudaSupport = false;}}",
            "llama-cpp-prism": "${prism}",
            "llama-cpp-mainline": "${mainline}",
        }
        for unit, build in runtimes.items():
            command = server.succeed("systemctl show " + unit + ".service -p ExecStart --value")
            assert build + "/bin/llama-server" in command, (unit, command)
            assert "--models-max" in command and "--offline" in command, command
            assert "/run/credentials/" + unit + ".service/api-key" in command, command
            assert "synthetic-test-key" not in command, command
            others = [b for u, b in runtimes.items() if u != unit]
            assert not any(o + "/bin/" in command for o in others), (unit, command)
    with subtest("a runtime restarts alone; restarting the main unit restarts them all"):
        def pids():
            return {u: server.succeed("systemctl show -p MainPID --value " + u + ".service").strip() for u in servers}
        def all_healthy():
            for u, (port, _) in servers.items():
                server.wait_until_succeeds("curl -fsS http://127.0.0.1:%d/health" % port, timeout=60)
        start = pids()
        server.succeed("systemctl restart llama-cpp-prism.service")
        all_healthy()
        alone = pids()
        assert alone["llama-cpp-prism"] != start["llama-cpp-prism"], alone
        assert alone["llama-cpp"] == start["llama-cpp"] and alone["llama-cpp-mainline"] == start["llama-cpp-mainline"], (start, alone)
        server.succeed("systemctl restart llama-cpp.service")
        all_healthy()
        together = pids()
        assert all(together[u] != alone[u] for u in servers), (alone, together)
  '';
}
