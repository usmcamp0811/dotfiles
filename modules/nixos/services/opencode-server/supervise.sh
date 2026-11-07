#!/usr/bin/env bash
# opencode-server-supervise: run the server, tell systemd when it is ready, and keep telling systemd it
# is alive only while it keeps answering. systemd's own watchdog (WatchdogSec) then restarts a server
# that is still running but no longer serving, which `Restart=on-failure` cannot notice.
#
#   opencode-server-supervise --url URL --interval S --timeout S --startup-grace S -- COMMAND [ARG...]
#
# The probe is an authenticated GET; the credentials are the ones the server itself was given
# (OPENCODE_SERVER_USERNAME / OPENCODE_SERVER_PASSWORD, already in the environment) and are handed to
# curl on stdin, never on a command line. Any 2xx counts as healthy.
#
# @curl@, @notify@ and @sleep@ are replaced with store paths when the module builds this script.
set -u

url=""
interval=30
timeout=15
grace=120
while [ $# -gt 0 ]; do
  case "$1" in
    --url) url="$2"; shift 2 ;;
    --interval) interval="$2"; shift 2 ;;
    --timeout) timeout="$2"; shift 2 ;;
    --startup-grace) grace="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "opencode-server-supervise: unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$url" ] || [ $# -eq 0 ]; then
  echo "usage: opencode-server-supervise --url URL [--interval S] [--timeout S] [--startup-grace S] -- COMMAND..." >&2
  exit 2
fi

# Outside systemd (a manual run, a test) there is nobody to tell: ignore the failure.
notify() { @notify@ "$@" 2>/dev/null || true; }

healthy() {
  local code
  code="$(printf 'user = "%s:%s"\n' "${OPENCODE_SERVER_USERNAME:-}" "${OPENCODE_SERVER_PASSWORD:-}" |
    @curl@ -sS -o /dev/null --max-time "$timeout" -K - -w '%{http_code}' "$url" 2>/dev/null)" || return 1
  case "$code" in
    2??) return 0 ;;
    *) return 1 ;;
  esac
}

"$@" &
child=$!

# systemd asks us to stop (it also signals the server directly): stop it and report a clean stop.
# shellcheck disable=SC2329  # called through the trap below
stop() {
  kill -TERM "$child" 2>/dev/null
  wait "$child" 2>/dev/null
  exit 0
}
trap stop TERM INT

# Starting up: wait until the server answers, but not forever.
started=$SECONDS
until healthy; do
  if ! kill -0 "$child" 2>/dev/null; then
    wait "$child"
    exit $?
  fi
  if [ $((SECONDS - started)) -ge "$grace" ]; then
    echo "opencode-server: did not answer at $url within ${grace}s; giving up" >&2
    kill -TERM "$child" 2>/dev/null
    wait "$child" 2>/dev/null
    exit 1
  fi
  @sleep@ 1 &
  wait $!
done
notify --ready "--status=serving"
notify WATCHDOG=1

# Serving: one probe per interval. A healthy answer is the proof of life systemd is waiting for; without
# it WatchdogSec runs out and systemd restarts the whole unit.
misses=0
while kill -0 "$child" 2>/dev/null; do
  @sleep@ "$interval" &
  wait $!
  kill -0 "$child" 2>/dev/null || break
  if healthy; then
    misses=0
    notify WATCHDOG=1 "--status=serving"
  else
    misses=$((misses + 1))
    echo "opencode-server: health probe failed ($misses in a row)" >&2
    notify "--status=not answering ($misses probe(s) failed)"
  fi
done

# The server ended by itself: pass its status on so Restart=on-failure sees it.
wait "$child"
exit $?
