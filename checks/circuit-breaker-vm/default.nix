# End-to-end test of fmf.services.circuit-breaker: the natively built upstream server
# (packages/circuit-breaker-server, 0.4.6 - no container) running as the module's own
# systemd units, with the real agent on a second VM.
#
# What it proves (each step is a `subtest`):
#   - the server starts, initialises persistent state, reports ready, is healthy
#   - generated secrets are 0400, root-only and appear in no unit/config file
#   - first-run bootstrap, then API token provisioning by the module
#   - the reconciler creates the topology from the exporter's inventory
#   - a second run is a no-op (idempotent); manual entities survive; canvas layout
#     is untouched; removal only retires; return un-retires
#   - declared state is separate from observed state: monitors report real
#     up/down from the live system
#   - an agent enrols (approval still required), reports telemetry, keeps its
#     identity across restarts, and runs a probe from its own vantage
#   - persistent data survives a server restart
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  fixtures = import ../../lib/circuit-breaker/tests.nix {inherit lib;};
  device = id: name: addr: {
    inherit id name;
    type = "device";
    parent = null;
    tags = [];
    attributes = lib.optionalAttrs (addr != null) {
      primaryAddress = addr;
      addressSource = "hint";
    };
    origin = {
      kind = "hint";
      ref = "vm-test";
    };
    state = "declared";
  };
  mon = id: target: host: port: name: {
    inherit id target host name;
    checkType = "tcp";
    config = {inherit port;};
    intervalSecs = 10;
  };
  extraResources = [
    (device "device/probe-target" "probe-target" null)
    (device "device/server-ip" "server-ip" "192.168.1.2")
  ];
  extraMonitors = [
    (mon "mon/device/probe-target/up" "device/probe-target" "192.168.1.2" 8000 "server api port")
    (mon "mon/device/probe-target/closed" "device/probe-target" "127.0.0.1" 9 "nothing listens here")
    (mon "mon/device/server-ip/tcp-8000" "device/server-ip" "192.168.1.2" 8000 "server https from the edge")
  ];
  inventory =
    fixtures.inv
    // {
      resources = fixtures.inv.resources ++ extraResources;
      monitors = fixtures.inv.monitors ++ extraMonitors;
    };
  isVault = r: r.id == "vm/vm-vault" || r.parent == "vm/vm-vault" || (r.id == "svc/vm-vault/vault");
  reduced =
    inventory
    // {
      resources = lib.filter (r: !(isVault r)) inventory.resources;
      relationships = lib.filter (r: !(lib.hasInfix "vm-vault" r.from || lib.hasInfix "vm-vault" r.to)) inventory.relationships;
      monitors = lib.filter (m: !(lib.hasInfix "vm-vault" m.target)) inventory.monitors;
    };
  inventoryFile = pkgs.writeText "inventory.json" (builtins.toJSON inventory);
  reducedFile = pkgs.writeText "inventory-reduced.json" (builtins.toJSON reduced);
  # A minimal flake with no inputs whose package is a pre-rendered inventory. It stands
  # in for the downstream repository's `circuit-breaker-inventory` package, so the real
  # `nix build git+<url>?rev=<sha>#circuit-breaker-inventory` path runs inside the
  # hardened sync unit without needing network access to fetch inputs.
  # The sandbox always provides /bin/sh; the inventory travels in the repository itself.
  gitFlake = pkgs.writeText "flake.nix" ''
    {
      description = "circuit-breaker git-sync test";
      outputs = _: {
        packages.x86_64-linux.circuit-breaker-inventory = derivation {
          name = "circuit-breaker-inventory.json";
          system = "x86_64-linux";
          builder = "/bin/sh";
          args = ["-c" "while IFS= read -r line || [ -n \"$line\" ]; do printf '%s\\n' \"$line\"; done < ''${./inventory.json} > $out"];
        };
      };
    }
  '';
  brokenFlake = pkgs.writeText "flake-broken.nix" ''
    { outputs = _: { packages.x86_64-linux.circuit-breaker-inventory = throw "evaluation failed on purpose"; }; }
  '';
  serverPackage = pkgs.fmf.circuit-breaker-server;
  syncPackage = pkgs.fmf.circuit-breaker-sync;
  agentPackage = pkgs.fmf.circuit-breaker-agent;
  expected = {
    hardware = lib.length (lib.filter (r: r.type == "host" || r.type == "device") inventory.resources);
    monitors = lib.length inventory.monitors;
    # the monitor assigned to the (not yet enrolled) agent is skipped, never run from the server
    monitorsBeforeAgent = lib.length inventory.monitors - 1;
  };
in
  pkgs.testers.runNixOSTest {
    name = "circuit-breaker-e2e";
    node.specialArgs = {inherit lib inputs;};
    # the vault-service module (imported by vault-agent) adds an overlay
    node.pkgsReadOnly = false;
    # Database initialisation, migrations and the first start take a few minutes.
    globalTimeout = 2400;

    nodes.server = {pkgs, ...}: {
      imports = [../../modules/nixos/services/vault-agent ../../modules/nixos/services/circuit-breaker];
      virtualisation = {
        memorySize = 4096;
        cores = 2;
        diskSize = 8192;
      };
      # TimescaleDB is under the Timescale licence
      nixpkgs.config.allowUnfree = true;
      environment.systemPackages = [pkgs.jq pkgs.curl pkgs.git pkgs.openssl];
      # a real (self-signed) certificate for the API, as an operator would supply one
      systemd.services.cb-test-cert = {
        wantedBy = ["multi-user.target"];
        requiredBy = ["circuit-breaker-api.service"];
        before = ["circuit-breaker-api.service" "circuit-breaker-sync.service"];
        path = [pkgs.openssl];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          install -d -m 0755 /var/lib/cb-test
          [ -s /var/lib/cb-test/server-cert.pem ] || openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
            -keyout /var/lib/cb-test/server-key.pem -out /var/lib/cb-test/server-cert.pem -days 2 \
            -subj /CN=circuit-breaker-test -addext subjectAltName=IP:192.168.1.2
          chmod 0600 /var/lib/cb-test/server-key.pem
        '';
      };
      fmf.services.circuit-breaker = {
        enable = true;
        server = {
          enable = true;
          package = serverPackage;
          listenAddress = "192.168.1.2";
          openFirewall = true;
          tls = {
            certFile = "/var/lib/cb-test/server-cert.pem";
            keyFile = "/var/lib/cb-test/server-key.pem";
          };
          secrets.generate = true;
          backup.enable = true;
        };
        flakeSync = {
          enable = true;
          package = syncPackage;
          inventory.source = inventoryFile;
          git = {
            enable = true;
            url = "file:///var/lib/cb-test/repo";
            extraAllowedSchemes = ["file"];
            ref = "main";
          };
          interval = "1d";
        };
        monitoring.remoteProbes."mon/device/server-ip/*" = "edge";
      };
    };

    nodes.edge = {pkgs, ...}: {
      imports = [../../modules/nixos/services/vault-agent ../../modules/nixos/services/circuit-breaker];
      environment.systemPackages = [pkgs.jq];
      fmf.services.circuit-breaker = {
        enable = true;
        agent = {
          enable = true;
          package = agentPackage;
          serverUrl = "https://192.168.1.2:8000";
          serverStaticPkFile = "/var/lib/cb-test/server-pk";
          tlsPinFile = "/var/lib/cb-test/tls-pin";
        };
      };
    };

    testScript = ''
      import json

      BASE = "https://192.168.1.2:8000/api/v1"
      SYNC_TOKEN = "/var/lib/circuit-breaker-sync/sync-token"
      admin_jwt = ""

      def api(method, path, token, body=None):
          data = f" -d '{json.dumps(body)}'" if body is not None else ""
          out = server.succeed(
              f"curl -ksS -X {method} -H 'Authorization: Bearer {token}' -H 'content-type: application/json'{data} {BASE}{path}"
          )
          return json.loads(out) if out.strip() else None

      def sync_token():
          return server.succeed(f"cat {SYNC_TOKEN}").strip()

      def sync_state():
          return json.loads(server.succeed("cat /var/lib/circuit-breaker-sync/state.json"))

      start_all()

      with subtest("services start in order, migrations run, application reports ready"):
          server.wait_for_unit("circuit-breaker-env.service")
          for u in ["postgres", "redis", "nats", "migrate", "api"]:
              server.wait_for_unit(f"circuit-breaker-{u}.service", timeout=240)
          server.wait_for_unit("circuit-breaker-ready.service", timeout=300)
          server.succeed("circuit-breaker-admin status")
          server.succeed("curl -ksfS https://192.168.1.2:8000/api/v1/readyz | jq -e '.ready == true and .checks.db == \"ok\" and .checks.redis == \"ok\"'")
          for w in ["discovery", "notification", "telemetry", "integration", "monitor-scheduler", "monitor-poll-0", "monitor-poll-1", "monitor-probe-dispatch"]:
              server.wait_for_unit(f"circuit-breaker-worker-{w}.service")
          server.succeed("circuit-breaker-admin psql -tAc \"select extname from pg_extension where extname = 'timescaledb'\" | grep -qx timescaledb")

      with subtest("least privilege: one unprivileged account, loopback-only internals, no secrets in argv"):
          users = server.succeed("ps -eo user:20,args | grep -E 'postgres|redis-server|nats-server|uvicorn|app.workers' | grep -v grep | awk '{print $1}' | sort -u").split()
          assert users == ["circuit-breaker"], users
          listening = server.succeed("ss -ltnH")
          for port in (15432, 16379, 14222):
              assert f"127.0.0.1:{port}" in listening, (port, listening)
              assert f"0.0.0.0:{port}" not in listening and f"*:{port}" not in listening
          assert "192.168.1.2:8000" in listening
          server.succeed("test \"$(id -u circuit-breaker)\" = 1500")
          # the discovery worker alone holds a capability
          for w in ["discovery", "telemetry"]:
              caps = server.succeed(f"systemctl show -p AmbientCapabilities circuit-breaker-worker-{w}.service").strip()
              assert (caps != "AmbientCapabilities=") == (w == "discovery"), (w, caps)
          # secrets reach processes through the environment, never the command line
          jwt = server.succeed("sed -n 's/^CB_JWT_SECRET=//p' /run/circuit-breaker-secrets/server.env").strip()
          redis_pw = server.succeed("sed -n 's/^CB_REDIS_PASSWORD=//p' /run/circuit-breaker-secrets/server.env").strip()
          nats = server.succeed("sed -n 's/^NATS_AUTH_TOKEN=//p' /run/circuit-breaker-secrets/server.env").strip()
          for secret in (jwt, redis_pw, nats):
              assert len(secret) >= 32
              # the secret goes through a file: putting it in grep's argv would make grep find itself
              server.succeed(f"printf %s {secret} > /tmp/secret-probe")
              server.fail("cat /proc/[0-9]*/cmdline | tr '\\0' ' ' | grep -Ff /tmp/secret-probe")
              server.succeed("rm -f /tmp/secret-probe")
          # one slice caps the whole stack
          server.succeed("systemctl show -p MemoryMax,CPUQuotaPerSecUSec circuit-breaker.slice | grep -q 'MemoryMax=2147483648'")
          server.succeed("systemctl show -p Slice circuit-breaker-api.service | grep -q circuit-breaker.slice")

      with subtest("generated secrets are root-only, stable, and in no unit file"):
          server.succeed("test \"$(stat -c %a /var/lib/circuit-breaker/secrets/server.env)\" = 400")
          server.succeed("test \"$(stat -c %a /run/circuit-breaker-secrets/server.env)\" = 400")
          secret = server.succeed("sed -n 's/^CB_JWT_SECRET=//p' /var/lib/circuit-breaker/secrets/server.env").strip()
          assert len(secret) == 64, secret
          server.fail(f"grep -rlF --exclude='*.tar' {secret} /etc /run/systemd /run/current-system")
          before = server.succeed("sha256sum /var/lib/circuit-breaker/secrets/server.env")
          server.succeed("systemctl restart circuit-breaker-env.service")
          assert before == server.succeed("sha256sum /var/lib/circuit-breaker/secrets/server.env"), "secrets must never be regenerated"
          # restarting the secrets unit restarts every service that requires it; wait for them
          server.wait_until_succeeds("curl -ksfS --max-time 5 https://192.168.1.2:8000/api/v1/readyz | jq -e '.ready == true'", timeout=300)
          server.wait_for_unit("circuit-breaker-ready.service")

      with subtest("first-run bootstrap then module-provisioned API token"):
          rc, out = server.execute("circuit-breaker-admin setup-token 2>/tmp/setup-token.err >/tmp/setup-token")
          assert rc == 0, server.succeed("cat /tmp/setup-token.err; curl -ksS https://192.168.1.2:8000/api/v1/bootstrap/status; ls -la /var/lib/circuit-breaker/data | head -20")
          setup = server.succeed("cat /tmp/setup-token").strip()
          resp = json.loads(server.succeed(
              "curl -ksS -X POST -H 'content-type: application/json' "
              + BASE + "/bootstrap/initialize -d '"
              + json.dumps({"setup_token": setup, "email": "admin@example.test", "password": "Synthetic-Test-Pass-2026!", "display_name": "Test Admin", "theme_preset": "dark"})
              + "'"))
          admin_jwt = resp["token"]
          server.fail("circuit-breaker-admin setup-token")  # no token once set up
          server.succeed("rm -f /tmp/setup-token")

      with subtest("manual entities exist before the first sync"):
          manual = api("POST", "/hardware", admin_jwt, {"name": "my-nas", "ip_address": "10.8.0.50", "tags": ["storage", "manual"], "notes": "hand made"})
          assert manual["id"]
          layout_data = {"nodes": {"hw-" + str(manual["id"]): {"x": 123, "y": 456}}}
          api("POST", "/graph/layout", admin_jwt, {"layout_data": json.dumps(layout_data)})

      with subtest("sync token is provisioned (0400) and the deployment inventory is applied"):
          server.succeed("systemctl start circuit-breaker-provision.service")
          # first-run setup replaced the vault key; the module restarts every application process once
          # so that none of them keeps the old key in memory
          server.succeed("test -e /var/lib/circuit-breaker/secrets/.vault-key-adopted")
          server.succeed(f"test \"$(stat -c %a {SYNC_TOKEN})\" = 400")
          server.wait_for_unit("circuit-breaker-sync.service", timeout=300)
          st = sync_state()
          assert st["last_attempt"]["result"] == "ok", st["last_attempt"]
          assert st["last_attempt"]["counts"]["create"] > 20, st["last_attempt"]

      tok = sync_token()

      with subtest("topology matches the inventory; ownership tags; nothing claimed as running"):
          hw = api("GET", "/hardware", tok)
          names = {h["name"] for h in hw}
          assert {"alpha", "bravo", "broken", "Core switch", "probe-target", "server-ip", "my-nas"} <= names, names
          owned = [h for h in hw if "nix:managed" in h["tags"]]
          assert len(owned) == ${toString expected.hardware}, (len(owned), ${toString expected.hardware})
          cu = {c["name"]: c for c in api("GET", "/compute-units", tok)}
          assert set(cu) == {"vm-vault", "vm-web"}, set(cu)  # vm-orphan is unplaced => not synced
          alpha = [h for h in hw if h["name"] == "alpha"][0]
          assert cu["vm-vault"]["hardware_id"] == alpha["id"], "VM must hang off its declared host"
          assert len(api("GET", "/monitors", tok)) == ${toString expected.monitorsBeforeAgent}
          svc = api("GET", "/services", tok)
          assert all(not s.get("status") for s in svc), "declared services must not be marked running"

      with subtest("manual entity and canvas layout are untouched"):
          nas = [h for h in api("GET", "/hardware", tok) if h["name"] == "my-nas"][0]
          assert nas["tags"] == ["manual", "storage"] and nas["notes"] == "hand made" and nas["ip_address"] == "10.8.0.50", nas
          assert api("GET", "/graph/layout", admin_jwt)["layout_data"] == layout_data

      with subtest("repeating the sync performs no writes"):
          server.succeed("systemctl restart circuit-breaker-sync.service")
          counts = sync_state()["last_attempt"]["counts"]
          assert set(counts) <= {"noop", "skip", "drift"}, counts
          server.succeed("cb-sync --dry-run --detailed-exitcode")  # exit 0 == nothing pending
          server.succeed("cb-sync --validate")
          server.succeed("cb-sync --status --live | grep -q 'drift: 0 pending'")

      with subtest("monitors report observed state independently of the declaration"):
          def ids():
              return {m["name"].split(" [nix:")[0]: m for m in api("GET", "/monitors", tok)}
          for name in ("server api port", "nothing listens here"):
              api("POST", f"/monitors/{ids()[name]['id']}/check", tok)
          def statuses(_):
              m = ids()
              return m["server api port"]["status"] == "up" and m["nothing listens here"]["status"] == "down"
          retry(statuses, timeout_seconds=120)
          # a declared-but-unreachable host is observed as such, never assumed healthy
          assert ids()["alpha reachability"]["status"] != "up"

      with subtest("removal retires (never deletes); returning un-retires"):
          server.succeed("cb-sync --apply --inventory ${reducedFile} --force-shrink")
          cu = {c["name"]: c for c in api("GET", "/compute-units", tok)}
          assert "nix:retired" in cu["vm-vault"]["tags"], cu["vm-vault"]
          assert [m for m in api("GET", "/monitors", tok) if "vm-vault" in m["name"] and m["enabled"]] == []
          assert api("GET", "/graph/layout", admin_jwt)["layout_data"] == layout_data
          server.succeed("cb-sync --apply --inventory ${inventoryFile}")
          cu = {c["name"]: c for c in api("GET", "/compute-units", tok)}
          assert "nix:retired" not in cu["vm-vault"]["tags"]
          assert [m for m in api("GET", "/monitors", tok) if "vm-vault" in m["name"] and not m["enabled"]] == []

      with subtest("an empty inventory can never retire anything"):
          server.succeed("echo '{\"schemaVersion\":1,\"kind\":\"circuit-breaker-inventory\",\"resources\":[],\"relationships\":[],\"monitors\":[]}' > /tmp/empty.json")
          rc = server.execute("cb-sync --apply --inventory /tmp/empty.json")[0]
          assert rc == 7, rc
          assert "nix:retired" not in str([h["tags"] for h in api("GET", "/hardware", tok)])

      def git(cmd):
          return server.succeed(f"cd /var/lib/cb-test/repo && git -c user.name=test -c user.email=test@example.invalid {cmd}")

      def commit(flake, inv, msg):
          server.succeed(f"cp {flake} /var/lib/cb-test/repo/flake.nix; cp {inv} /var/lib/cb-test/repo/inventory.json")
          git("add flake.nix inventory.json")
          git(f"commit -qm '{msg}'")
          server.succeed("chown -R circuit-breaker-sync /var/lib/cb-test/repo")
          return git("rev-parse HEAD").strip()

      with subtest("git-driven sync: new trusted revision is evaluated by the hardened unit and applied"):
          server.succeed("git config --global --add safe.directory /var/lib/cb-test/repo")  # root inspects a repo owned by the service user
          server.succeed("mkdir -p /var/lib/cb-test/repo && cd /var/lib/cb-test/repo && git init -q -b main")
          rev1 = commit("${gitFlake}", "${reducedFile}", "reduced topology")
          server.succeed("systemctl start circuit-breaker-sync-git.service")
          st = sync_state()
          assert st["last_success"]["revision"] == rev1, (rev1, st["last_success"])
          assert st["last_attempt"]["result"] == "ok", st["last_attempt"]
          # the git revision describes DESIRED state: vm-vault is no longer declared => retired
          cu = {c["name"]: c for c in api("GET", "/compute-units", tok)}
          assert "nix:retired" in cu["vm-vault"]["tags"], cu["vm-vault"]["tags"]
          server.succeed("test \"$(stat -c %a /var/lib/circuit-breaker-sync/state.json)\" = 660")

      with subtest("git-driven sync: an unchanged revision is not evaluated again"):
          out = server.succeed("systemctl start circuit-breaker-sync-git.service; journalctl -u circuit-breaker-sync-git -n 5 -o cat")
          assert "already synchronised" in out, out

      with subtest("git-driven sync: a revision that fails to evaluate keeps the last known good topology"):
          bad = commit("${brokenFlake}", "${reducedFile}", "broken evaluation")
          rc, _ = server.execute("systemctl start circuit-breaker-sync-git.service")
          assert rc != 0
          st = sync_state()
          assert st["last_success"]["revision"] == rev1, st["last_success"]
          assert st["attempts"][bad]["count"] == 1, st["attempts"]
          cu = {c["name"]: c for c in api("GET", "/compute-units", tok)}
          assert "nix:retired" in cu["vm-vault"]["tags"], "a failed evaluation must change nothing"
          # the broken revision is not hammered: inside the backoff window it is skipped
          out = server.succeed("systemctl start circuit-breaker-sync-git.service; journalctl -u circuit-breaker-sync-git -n 5 -o cat")
          assert "next retry after" in out, out

      with subtest("git-driven sync: the next good revision recovers; deployment sync restores the declared set"):
          rev3 = commit("${gitFlake}", "${inventoryFile}", "restore vault")
          server.succeed("systemctl start circuit-breaker-sync-git.service")
          assert sync_state()["last_success"]["revision"] == rev3
          cu = {c["name"]: c for c in api("GET", "/compute-units", tok)}
          assert "nix:retired" not in cu["vm-vault"]["tags"]
          server.succeed("systemctl restart circuit-breaker-sync.service")

      with subtest("agent enrols only after approval, then reports telemetry"):
          # the server's public identity key straight from the application, and the SPKI pin of the
          # certificate it serves
          pk = server.succeed("circuit-breaker-admin agent-key").strip()
          assert len(pk) == 64 and all(c in "0123456789abcdef" for c in pk), pk
          # upstream's own install endpoint works too: it reads the published public certificate
          server.succeed("test \"$(stat -c %a /var/lib/circuit-breaker/data/tls/fullchain.pem)\" = 644")
          # repeated so that both API worker processes answer: each must hold the adopted vault key
          for _ in range(12):
              server.succeed("curl -ksfS --max-time 20 https://192.168.1.2:8000/install-agent.sh -o /tmp/install-agent.sh")
          server.succeed(f"grep -qx 'CB_SERVER_STATIC_PK=\"{pk}\"' /tmp/install-agent.sh")
          # the API serves the certificate we gave it, so the SPKI pin comes from that file
          pin = server.succeed("openssl x509 -in /var/lib/cb-test/server-cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64").strip()
          edge.succeed("mkdir -p /var/lib/cb-test")
          edge.succeed(f"printf %s {pk} > /var/lib/cb-test/server-pk; printf %s {pin} > /var/lib/cb-test/tls-pin")
          edge.succeed("systemctl start cb-agent.service")
          edge.wait_for_unit("cb-agent.service")
          def pending(_):
              return len(api("GET", "/agents/pending", admin_jwt)) == 1
          retry(pending, timeout_seconds=120)
          agents = api("GET", "/agents", admin_jwt)
          assert all(a["status"] != "active" for a in agents), "must not be active before approval"
          agent_id = api("GET", "/agents/pending", admin_jwt)[0]["id"]
          api("POST", f"/agents/{agent_id}/approve", admin_jwt, {"host_link_action": "unlinked", "capabilities": {"host_telemetry": True, "remote_probe": True, "local_discovery": False}})
          def reporting(_):
              a = [x for x in api("GET", "/agents", admin_jwt) if x["id"] == agent_id][0]
              return a["status"] == "active" and a["last_seen_at"]
          retry(reporting, timeout_seconds=180)
          def has_telemetry(_):
              t = api("GET", f"/agents/{agent_id}/telemetry", admin_jwt)
              return bool(t.get("latest"))
          retry(has_telemetry, timeout_seconds=180)
          edge.succeed("test \"$(stat -c %a /var/lib/cb-agent/device.key)\" = 600")
          edge.succeed("cb-agent status > /tmp/agent-status; grep -q 'link: accepted' /tmp/agent-status")

      with subtest("agent identity persists across restarts; no re-approval"):
          fp = edge.succeed("cb-agent status | sed -n 's/^fingerprint: //p'").strip()
          edge.succeed("systemctl restart cb-agent.service")
          edge.wait_for_unit("cb-agent.service")
          def linked_again(_):
              return "link: accepted" in edge.succeed("cb-agent status")
          retry(linked_again, timeout_seconds=120)
          assert fp == edge.succeed("cb-agent status | sed -n 's/^fingerprint: //p'").strip()
          assert len(api("GET", "/agents", admin_jwt)) == 1, "restart must not create a second agent"

      with subtest("monitor assigned to the agent runs from the agent's vantage"):
          server.succeed("systemctl restart circuit-breaker-sync.service")
          m = [x for x in api("GET", "/monitors", tok) if x["name"].startswith("server https from the edge")][0]
          assert m["probe_agent_id"] == agent_id and m["probe_mode"] == "agent", m
          api("POST", f"/monitors/{m['id']}/check", tok)
          def probed(_):
              x = [y for y in api("GET", "/monitors", tok) if y["id"] == m["id"]][0]
              return x["status"] == "up"
          retry(probed, timeout_seconds=180)

      with subtest("state survives a restart of the whole stack"):
          before_ids = sorted(h["id"] for h in api("GET", "/hardware", tok))
          server.succeed("systemctl restart circuit-breaker-postgres.service circuit-breaker-api.service")
          server.wait_for_unit("circuit-breaker-ready.service")
          server.succeed("systemctl restart circuit-breaker-ready.service")
          assert before_ids == sorted(h["id"] for h in api("GET", "/hardware", tok))
          assert api("GET", "/graph/layout", admin_jwt)["layout_data"] == layout_data
          assert len(api("GET", "/agents", admin_jwt)) == 1
          server.succeed("systemctl restart circuit-breaker-sync.service")
          assert set(sync_state()["last_attempt"]["counts"]) <= {"noop", "skip", "drift"}

      with subtest("the whole stack stays inside its resource cap (measured, not assumed)"):
          mem = int(server.succeed("systemctl show -p MemoryCurrent --value circuit-breaker.slice").strip())
          peak = int(server.succeed("systemctl show -p MemoryPeak --value circuit-breaker.slice").strip())
          print(f"circuit-breaker.slice after the full workflow: {mem // 2**20} MiB in use, {peak // 2**20} MiB peak (cap 2048 MiB)")
          assert 0 < mem < 2 * 2**30 and peak < 2 * 2**30, (mem, peak)

      with subtest("snapshot backup contains the vault key (so it must be treated as a secret)"):
          server.succeed("systemctl start circuit-breaker-snapshot.service")
          server.succeed("ls /var/lib/circuit-breaker/data/backups/*.tar.gz")
          server.succeed("test \"$(stat -c %a $(ls /var/lib/circuit-breaker/data/backups/*.tar.gz | head -1))\" = 600")
    '';
  }
