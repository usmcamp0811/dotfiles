{pkgs, ...}: let
  # Deliberately invalid, tiny files: router startup/listing must not load them.
  fakeModel = pkgs.writeText "test-model.gguf" "not-real-model-weights";
in pkgs.testers.nixosTest {
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
        models = {
          test-a = {package = fakeModel; contextSize = 2048;};
          test-b = {package = fakeModel; contextSize = 4096;};
        };
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
    server.start()
    server.wait_for_unit("llama-cpp.service")
    server.wait_until_succeeds("curl -fsS http://127.0.0.1:18080/health")
    with subtest("unauthenticated inference is rejected before model loading"):
        result = server.succeed("curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d '{\"model\":\"test-a\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}' http://127.0.0.1:18080/v1/chat/completions")
        assert result.strip() == "401", result
    with subtest("authenticated model listing works without loading weights"):
        data = json.loads(server.succeed("curl -fsS -H 'Authorization: Bearer synthetic-test-key-not-a-production-secret' http://127.0.0.1:18080/v1/models"))
        assert {m["id"] for m in data["data"]} == {"test-a", "test-b"}, data
    with subtest("server reads credentials through systemd, not public command line"):
        command = server.succeed("systemctl show llama-cpp.service -p ExecStart --value")
        assert "--models-max" in command and "--offline" in command, command
        assert "/run/credentials/llama-cpp.service/api-key" in command, command
        assert "synthetic-test-key" not in command, command
  '';
}
