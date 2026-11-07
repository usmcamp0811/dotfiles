# The watchdog around `opencode serve`: a small supervisor plus the systemd settings that go with it.
# Shared by the module and by checks/opencode-server-watchdog, so the test exercises exactly what the
# module ships.
{
  pkgs,
  lib,
  systemd ? pkgs.systemd,
}: let
  supervise =
    pkgs.writeShellScript "opencode-server-supervise"
    (builtins.replaceStrings ["@curl@" "@notify@" "@sleep@"]
      ["${pkgs.curl}/bin/curl" "${systemd}/bin/systemd-notify" "${pkgs.coreutils}/bin/sleep"]
      (builtins.readFile ./supervise.sh));
in {
  inherit supervise;

  # `command` (a shell command line) run under the supervisor.
  wrap = {
    url,
    interval,
    timeout,
    startupGrace,
    ...
  }: command: "${supervise} --url ${lib.escapeShellArg url} --interval ${toString interval} --timeout ${toString timeout} --startup-grace ${toString startupGrace} -- ${command}";

  # Unit settings. The supervisor pings systemd only after a healthy answer, and pings are at most
  # interval + timeout apart while healthy, so `failures` missed pings in a row is what trips systemd.
  serviceConfig = {
    interval,
    timeout,
    failures,
    startupGrace,
    ...
  }: {
    Type = "notify";
    NotifyAccess = "all"; # systemd-notify runs as a child of the supervisor
    WatchdogSec = (interval + timeout) * failures;
    TimeoutStartSec = startupGrace + 30;
    # A hung server may ignore SIGTERM; do not wait the default 90 s for it before SIGKILL.
    TimeoutStopSec = 20;
  };
}
