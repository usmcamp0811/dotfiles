{pkgs, ...}: let
  # The real pinned Strata Python server (pkgs.fmf.strata.root/py: no engine, no CUDA), driven by the module's real
  # systemd unit with the server's scripted MOCK engine. Weights and tokenizer are tiny fakes: this proves the
  # service wiring, credential handling and API/auth behaviour, not inference.
  strata = pkgs.fmf.strata;
  mockPackage =
    (pkgs.writeShellScriptBin "strata-server" ''
      exec ${strata.py}/bin/python ${strata.root}/serve/server.py "$@"
    '')
    // {
      enginePath = "/unused-by-the-mock-engine";
      tokenizerFor = _: pkgs.emptyDirectory;
    };
  fakeModel = pkgs.writeText "fake-qwen36.gguf" "not-real-model-weights";
  catalog = (import ../../lib/strata-models {}).strataModels {inherit pkgs;};
  testCatalog = pkgs.lib.mapAttrs (_: model: model // {package = fakeModel;}) catalog;
  id = "qwen3.6-35b-a3b-ud-q4_k_xl";
  key = "synthetic-test-key-not-a-production-secret";
in
  pkgs.testers.nixosTest {
    name = "strata-authenticated-server";
    nodes.server = {config, lib, ...}: {
      imports = [../../modules/nixos/services/strata];
      # Synthetic credential only; Vault never runs in this test.
      options.fmf.services.vault-agent = lib.mkOption {
        type = lib.types.attrs;
        default = {enable = false; services = {};};
      };
      config = {
        virtualisation.memorySize = 2048;
        fmf.services.strata = {
          enable = true;
          engine = "mock";
          package = mockPackage;
          models = testCatalog;
          host = "127.0.0.1";
          port = 18081;
          apiKeyFile = "/run/strata-test-key";
          memoryMax = null;
        };
        systemd.services.strata-test-key = {
          requiredBy = ["strata.service"];
          before = ["strata.service"];
          serviceConfig.Type = "oneshot";
          script = ''
            umask 077
            printf '%s' '${key}' > /run/strata-test-key
          '';
        };
        environment.systemPackages = [pkgs.curl];
      };
    };

    testScript = ''
      import json

      auth = "-H 'Authorization: Bearer ${key}'"
      url = "http://127.0.0.1:18081"
      server.start()
      server.wait_for_unit("strata.service")
      server.wait_until_succeeds(f"curl -fsS {url}/health")

      # health is open and says what is served and that a key is required
      health = json.loads(server.succeed(f"curl -fsS {url}/health"))
      assert health["service"] == "strata", health
      assert health["api_key"] is True, health
      assert health["model"] == "${id}", health

      # authentication is enforced everywhere else
      for path in ["/v1/models", "/metrics", "/status", "/props", "/slots"]:
          code = server.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' {url}{path}").strip()
          assert code == "401", (path, code)
      wrong = server.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' -H 'Authorization: Bearer nope' {url}/v1/models").strip()
      assert wrong == "401", wrong
      body = '{"model":"x","messages":[{"role":"user","content":"hi"}]}'
      code = server.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' -H 'Content-Type: application/json' -d '{body}' {url}/v1/chat/completions").strip()
      assert code == "401", code

      # with the key: exactly one model, under the configured id
      models = json.loads(server.succeed(f"curl -fsS {auth} {url}/v1/models"))
      assert [m["id"] for m in models["data"]] == ["${id}"], models

      # a request naming some other model is answered by the one served model, so one id is the honest listing
      other = '{"model":"some-other-model","messages":[{"role":"user","content":"hi"}]}'
      reply = json.loads(server.succeed(f"curl -fsS {auth} -H 'Content-Type: application/json' -d '{other}' {url}/v1/chat/completions"))
      assert reply["model"] == "${id}", reply
      assert reply["choices"][0]["message"]["content"], reply

      # streaming (SSE)
      stream = '{"model":"x","stream":true,"messages":[{"role":"user","content":"hi"}]}'
      sse = server.succeed(f"curl -sN {auth} -H 'Content-Type: application/json' -d '{stream}' {url}/v1/chat/completions")
      assert "data: " in sse and "[DONE]" in sse, sse[:300]

      # the key is never in argv, the unit's environment text or the world-readable run config
      pid = server.succeed("systemctl show -p MainPID --value strata.service").strip()
      server.fail(f"grep -a '${key}' /proc/{pid}/cmdline")
      server.fail("systemctl show strata.service | grep -a '${key}'")
      server.fail("grep -rl '${key}' /nix/store 2>/dev/null")

      # service user, state directory and permissions
      assert server.succeed("stat -c '%U:%a' /var/lib/strata").strip() == "strata:750"
      assert server.succeed("ps -o user= -p " + pid).strip() == "strata"

      # failure behaviour: no or malformed credentials must stop it from starting, never serve unauthenticated
      server.succeed("systemctl stop strata.service")
      server.succeed("rm -f /run/strata-test-key")
      server.fail("systemctl start strata.service")
      server.succeed("journalctl -u strata.service --no-pager | grep 'missing or unreadable'")
      server.succeed("printf short > /run/strata-test-key")
      server.fail("systemctl start strata.service")
      server.succeed("journalctl -u strata.service --no-pager | grep 'must be 32-256 printable'")
      server.fail(f"curl -fsS {url}/health")
    '';
  }
