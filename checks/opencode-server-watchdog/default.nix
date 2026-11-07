# The opencode-server watchdog under real systemd. The unit is built from the same helper the module
# uses (modules/nixos/services/opencode-server/watchdog.nix), and runs unprivileged like the real one,
# but the server is a tiny stand-in that answers like `opencode serve` (401 without credentials, 200 on
# /global/health with them), so it can be frozen and killed on demand.
{
  pkgs,
  lib,
  ...
}: let
  watchdog = import ../../modules/nixos/services/opencode-server/watchdog.nix {inherit pkgs lib;};

  password = "watchdog-test-password-0123456789";

  server = pkgs.writeText "fake-opencode.py" ''
    import base64
    import http.server
    import os
    import sys
    import time

    time.sleep(float(os.environ.get("FAKE_START_DELAY", "0")))
    args = sys.argv[1:]
    host = args[args.index("--hostname") + 1]
    port = int(args[args.index("--port") + 1])
    credentials = "%s:%s" % (os.environ["OPENCODE_SERVER_USERNAME"], os.environ["OPENCODE_SERVER_PASSWORD"])
    expect = "Basic " + base64.b64encode(credentials.encode()).decode()


    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.headers.get("Authorization") != expect:
                self.send_response(401)
                self.end_headers()
                return
            body = b'{"healthy":true}'
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass


    http.server.ThreadingHTTPServer((host, port), Handler).serve_forever()
  '';
  fake = pkgs.writeShellScriptBin "opencode" ''exec ${pkgs.python3}/bin/python3 ${server} "$@"'';

  # short numbers so the test is quick: the unit's watchdog is (2 + 2) * 2 = 8 s
  params = {
    interval = 2;
    timeout = 2;
    failures = 2;
  };

  unit = {
    port,
    startupGrace,
    env ? "",
  }: {
    serviceConfig =
      {
        User = "agent";
        Restart = "on-failure";
        RestartSec = 2;
        NoNewPrivileges = true;
        ExecStart = pkgs.writeShellScript "start-${toString port}" ''
          export OPENCODE_SERVER_USERNAME=opencode OPENCODE_SERVER_PASSWORD=${password}
          ${env}
          exec ${watchdog.wrap (params // {inherit startupGrace; url = "http://127.0.0.1:${toString port}/global/health";}) "${fake}/bin/opencode serve --hostname 127.0.0.1 --port ${toString port}"}
        '';
      }
      // watchdog.serviceConfig (params // {inherit startupGrace;});
  };
in
  pkgs.testers.runNixOSTest {
    name = "opencode-server-watchdog";

    nodes.machine = {
      users.users.agent.isNormalUser = true;
      systemd.services = {
        opencode-fake = (unit {port = 4096; startupGrace = 30;}) // {wantedBy = ["multi-user.target"];};
        # never answers within its (short) startup grace; started by hand
        opencode-slow = unit {port = 4097; startupGrace = 4; env = "export FAKE_START_DELAY=30";};
      };
    };

    testScript = ''
      auth = "-u opencode:${password}"
      health = f"curl -sf --max-time 3 {auth} http://127.0.0.1:4096/global/health"


      def restarts():
          return int(machine.succeed("systemctl show -p NRestarts --value opencode-fake").strip())


      def server_pid():
          main = machine.succeed("systemctl show -p MainPID --value opencode-fake").strip()
          return machine.succeed(f"pgrep -P {main} -f fake-opencode").strip()


      machine.wait_for_unit("opencode-fake.service")  # Type=notify: active only once it answers
      machine.succeed(health + " | grep -q healthy")
      machine.succeed("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4096/global/health | grep -q 401")
      machine.succeed("systemctl show -p WatchdogUSec --value opencode-fake | grep -qx 8s")
      machine.succeed("systemctl show -p Type --value opencode-fake | grep -qx notify")

      with subtest("a healthy server is left alone, across several watchdog periods"):
          machine.sleep(25)
          assert restarts() == 0, "the watchdog restarted a healthy server"
          machine.succeed(health)

      with subtest("a hung server (alive, not answering) is restarted by the watchdog"):
          old = server_pid()
          machine.succeed(f"kill -STOP {old}")
          machine.wait_until_succeeds('test "$(systemctl show -p NRestarts --value opencode-fake)" -ge 1', timeout=90)
          machine.wait_until_succeeds(health, timeout=90)
          machine.fail(f"kill -0 {old}")  # the frozen server is gone, not left behind
          machine.succeed("journalctl -u opencode-fake --no-pager | grep -i 'watchdog'")
          assert server_pid() != old

      with subtest("a crashed server is restarted"):
          before = restarts()
          machine.succeed(f"kill -9 {server_pid()}")
          machine.wait_until_succeeds(f'test "$(systemctl show -p NRestarts --value opencode-fake)" -gt {before}', timeout=60)
          machine.wait_until_succeeds(health, timeout=60)

      with subtest("a stop is prompt, and leaves nothing running"):
          machine.succeed("timeout 15 systemctl stop opencode-fake")
          machine.fail("pgrep -u agent python3")
          machine.fail(health)

      with subtest("a server that never answers fails its start instead of hanging"):
          machine.fail("systemctl start opencode-slow")
          machine.succeed("journalctl -u opencode-slow --no-pager | grep 'did not answer'")
          machine.fail("pgrep -u agent python3")
    '';
  }
