{pkgs, ...}: let
  # The model router with the real pinned Strata Python server (no engine, no CUDA) behind it: the module's real units,
  # the real router, polkit and systemd, and the server's scripted MOCK engine. Weights and tokenizer are tiny fakes.
  # It proves the switching, the key handling and the unit control, not inference.
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
  q4 = "qwen3.6-35b-a3b-ud-q4_k_xl";
  q6 = "qwen3.6-35b-a3b-ud-q6_k_xl";
  q8 = "qwen3.6-35b-a3b-q8_0";
  key = "synthetic-test-key-not-a-production-secret";
in
  pkgs.testers.nixosTest {
    name = "strata-model-router";
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
          lazyLoad = true;
          router = {
            enable = true;
            models = {
              ${q4} = {};
              ${q6} = {};
              ${q8} = {};
            };
            startTimeoutSeconds = 60;
          };
        };
        systemd.services.write-test-key = {
          requiredBy = ["strata.service"];
          before = ["strata.service"];
          serviceConfig.Type = "oneshot";
          script = ''
            umask 077
            printf '%s' '${key}' > /run/strata-test-key
          '';
        };
        # Something the router must NOT be able to stop.
        systemd.services.canary = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        };
        environment.systemPackages = [pkgs.curl];
      };
    };

    testScript = ''
      import json

      auth = "-H 'Authorization: Bearer ${key}'"
      url = "http://127.0.0.1:18081"
      ids = ["${q4}", "${q6}", "${q8}"]
      units = {i: f"strata-{i}.service" for i in ids}

      def active(i):
          return server.succeed(f"systemctl is-active {units[i]} || true").strip()

      def ask(model):
          body = json.dumps({"model": model, "messages": [{"role": "user", "content": "hi"}]})
          return json.loads(server.succeed(f"curl -fsS {auth} -H 'Content-Type: application/json' -d '{body}' {url}/v1/chat/completions"))

      server.start()
      server.wait_for_unit("strata.service")
      server.wait_until_succeeds(f"curl -fsS {url}/health")

      # nothing runs until a model is asked for; the router itself answers /health and says what it can serve
      health = json.loads(server.succeed(f"curl -fsS {url}/health"))
      assert health["router"] is True and health["api_key"] is True and health["active"] is None, health
      assert health["models"] == sorted(ids), health
      for i in ids:
          assert active(i) == "inactive", (i, active(i))

      # authentication is the router's, and applies to everything but /health
      for path in ["/v1/models", "/metrics", "/status"]:
          code = server.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' {url}{path}").strip()
          assert code == "401", (path, code)
      code = server.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' -H 'Authorization: Bearer nope' {url}/v1/models").strip()
      assert code == "401", code
      code = server.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' -H 'x-api-key: ${key}' {url}/v1/models").strip()
      assert code == "200", code

      # listing every model needs no model to be running
      listing = json.loads(server.succeed(f"curl -fsS {auth} {url}/v1/models"))
      assert [m["id"] for m in listing["data"]] == sorted(ids), listing
      for i in ids:
          assert active(i) == "inactive", (i, active(i))

      # the first request starts exactly that model's unit and is answered by it
      assert ask("${q8}")["model"] == "${q8}"
      assert active("${q8}") == "active" and active("${q4}") == "inactive" and active("${q6}") == "inactive"

      # naming another model stops this one (the GPU is free for it) and starts the other
      assert ask("${q4}")["model"] == "${q4}"
      assert active("${q4}") == "active" and active("${q8}") == "inactive" and active("${q6}") == "inactive"
      assert ask("${q6}")["model"] == "${q6}"
      assert active("${q6}") == "active" and active("${q4}") == "inactive"

      # a request naming nothing the router knows goes to the model that is running, without switching
      assert ask("some-other-model")["model"] == "${q6}"
      assert active("${q6}") == "active" and active("${q4}") == "inactive" and active("${q8}") == "inactive"
      health = json.loads(server.succeed(f"curl -fsS {url}/health"))
      assert health["active"] == "${q6}", health

      # streaming (SSE) passes through, switching included
      stream = json.dumps({"model": "${q4}", "stream": True, "messages": [{"role": "user", "content": "hi"}]})
      sse = server.succeed(f"curl -sN {auth} -H 'Content-Type: application/json' -d '{stream}' {url}/v1/chat/completions")
      assert "data: " in sse and "[DONE]" in sse, sse[:300]
      assert active("${q4}") == "active" and active("${q6}") == "inactive"

      # the models do not know the client's key: it is not theirs, and theirs is not the client's
      port = 18100 + sorted(ids).index("${q4}")
      code = server.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' {auth} http://127.0.0.1:{port}/v1/models").strip()
      assert code == "401", code
      backend_key = server.succeed("cat /run/strata/backend-key").strip()
      assert backend_key != "${key}" and len(backend_key) == 64, "the models share the client's key"
      code = server.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' -H 'Authorization: Bearer {backend_key}' http://127.0.0.1:{port}/v1/models").strip()
      assert code == "200", code
      pid = server.succeed("systemctl show -p MainPID --value strata-${q4}.service").strip()
      server.fail(f"grep -a '${key}' /proc/{pid}/environ")
      server.fail(f"grep -a '${key}' /proc/{pid}/cmdline")
      # the files of the Strata units in the store (not the test's own, which hold the synthetic key to write it)
      files = "find /nix/store -maxdepth 1 \\( -name '*-strata-*' -o -name '*unit-strata*' \\) ! -name '*test*'"
      assert int(server.succeed(files + " | wc -l").strip()) > 5, "found no unit files to check"
      server.fail(files + " | xargs grep -rl '${key}'")
      server.fail(files + " | xargs grep -rl '" + backend_key + "'")
      assert server.succeed("stat -c '%U:%a' /run/strata/backend-key").strip() == "strata:600"

      # the router may control the model units and nothing else
      server.succeed("runuser -u strata -- systemctl --no-ask-password stop strata-${q6}.service")
      server.fail("runuser -u strata -- systemctl --no-ask-password stop canary.service")
      assert server.succeed("systemctl is-active canary.service").strip() == "active"
      server.succeed("grep -q manage-units /etc/polkit-1/rules.d/10-nixos.rules")

      # a restart of the router (a rotated key, a deploy) takes the running model down with it, and the next
      # request starts again under a fresh key
      server.succeed("systemctl restart strata.service")
      server.wait_until_succeeds(f"curl -fsS {url}/health")
      for i in ids:
          assert active(i) == "inactive", (i, active(i))
      new_backend_key = server.succeed("cat /run/strata/backend-key").strip()
      assert new_backend_key != backend_key, "the models' key was not renewed"
      assert ask("${q8}")["model"] == "${q8}"
      assert active("${q8}") == "active"

      # stopping the router frees every model
      server.succeed("systemctl stop strata.service")
      for i in ids:
          assert active(i) == "inactive", (i, active(i))
      server.fail(f"curl -fsS {url}/health")
    '';
  }
