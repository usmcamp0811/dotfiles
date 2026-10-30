{pkgs, ...}: let
  # Deliberately invalid, tiny files: router startup/listing must not load them.
  fakeModel = pkgs.writeText "test-model.gguf" "not-real-model-weights";
  catalog = (import ../../lib/llama-cpp-models {}).llamaCppModels {inherit pkgs;};
  # Exercise every real ID/limit, substituting tiny files for weights only.
  testModels = pkgs.lib.mapAttrs (_: model: model // {package = fakeModel;}) catalog;
# OpenCode 1.19.4's usable() uses context minus max output when limit.input is
# absent. Check the shared default without realizing the GGUF derivation.
in assert pkgs.lib.all (model: model.contextSize == 32768
  && model.contextSize - model.maxOutputTokens == 30720) (builtins.attrValues catalog);
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
    virtualisation.memorySize = 2048;
    fmf.services.llama-cpp = {
      enable = true;
      package = pkgs.llama-cpp.override {cudaSupport = false;};
      host = "127.0.0.1";
      apiKeyFile = "/run/llama-test-key";
      router = {
        enable = true;
        models = testModels;
      };
    };
    systemd.services.llama-test-key = {
      requiredBy = ["llama-cpp.service"];
      before = ["llama-cpp.service"];
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
    server.start()
    server.wait_for_unit("llama-cpp.service")
    server.wait_until_succeeds("curl -fsS http://127.0.0.1:18080/health")
    with subtest("unauthenticated inference is rejected before model loading"):
        result = server.succeed("curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d '{\"model\":\"gpt-oss-20b\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}' http://127.0.0.1:18080/v1/chat/completions")
        assert result.strip() == "401", result
    with subtest("authenticated model listing works without loading weights"):
        data = json.loads(server.succeed("curl -fsS -H 'Authorization: Bearer synthetic-test-key-not-a-production-secret' http://127.0.0.1:18080/v1/models"))
        assert {m["id"] for m in data["data"]} == {"gpt-oss-20b", "qwen3.6-35b-a3b", "qwen3.5-9b", "qwen3-coder-30b-a3b", "devstral-small-2"}, data
    with subtest("every preset passes worker argument parsing and reaches the fake GGUF"):
        for model in sorted(m["id"] for m in data["data"]):
            before = int(server.succeed("journalctl -u llama-cpp.service --no-pager | grep -c 'invalid magic' || true").strip())
            payload = json.dumps({"model": model, "messages": [{"role": "user", "content": "hello"}], "max_tokens": 1})
            status, response = server.execute("curl --max-time 3 -sS -o /tmp/model-error -w '%{http_code}' -H 'Authorization: Bearer synthetic-test-key-not-a-production-secret' -H 'Content-Type: application/json' --data " + shlex.quote(payload) + " http://127.0.0.1:18080/v1/chat/completions")
            assert status == 28 or (status == 0 and response.strip() in {"500", "503"}), (model, status, response)
            # Expected failure is invalid model bytes, not an unknown preset
            # flag. This validates worker CLI options without real weights.
            # b9190 can wait indefinitely after the fake worker fails; bound
            # the negative request and reset this isolated fixture each time.
            server.wait_until_succeeds("test $(journalctl -u llama-cpp.service --no-pager | grep -c 'invalid magic') -gt " + str(before), timeout=10)
            server.succeed("systemctl kill --signal=KILL llama-cpp.service && systemctl stop llama-cpp.service && systemctl reset-failed llama-cpp.service && systemctl start llama-cpp.service")
            server.wait_until_succeeds("curl -fsS http://127.0.0.1:18080/health", timeout=30)
    with subtest("server reads credentials through systemd, not public command line"):
        command = server.succeed("systemctl show llama-cpp.service -p ExecStart --value")
        assert "--models-max" in command and "--offline" in command, command
        assert "/run/credentials/llama-cpp.service/api-key" in command, command
        assert "synthetic-test-key" not in command, command
  '';
}
