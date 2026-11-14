#!/usr/bin/env bash
# Keeps `opencode attach` alive across opencode-server outages.
#
#   attach-loop.sh <health-url> -- <attach command...>
#
# Credentials for the health probe come from OPENCODE_SERVER_USERNAME / OPENCODE_SERVER_PASSWORD (the same
# variables `opencode attach` reads). OPENCODE_REMOTE_POLL sets the probe interval in seconds (default 5).
#
#  * The attach TUI runs in the foreground of this terminal (stdin/tty stay connected).
#  * A watcher probes the server. When it stops answering it rings the terminal bell, sets the terminal title
#    and sends a desktop notification if notify-send exists. (It never prints into the screen: the TUI owns it.)
#  * When the server answers again the watcher stops the attach process, and this script attaches again. A stuck
#    TUI therefore does not need a manual restart. Sessions live on the server, so they are still there.
#  * If attach exits by itself and the server is down, wait for it, then attach again. If attach exits by itself
#    and the server is healthy, that was the user (or an error): exit with attach's status.
set -u

curl=@curl@
health_url=${1:?usage: attach-loop.sh <health-url> -- <attach command...>}
shift
[ "${1:-}" = "--" ] && shift
[ "$#" -gt 0 ] || { echo "attach-loop: no command given" >&2; exit 2; }

poll=${OPENCODE_REMOTE_POLL:-5}

healthy() {
  printf 'user = "%s:%s"\n' "${OPENCODE_SERVER_USERNAME:-}" "${OPENCODE_SERVER_PASSWORD:-}" |
    "$curl" -fsS -m 5 -K - -o /dev/null "$health_url" 2>/dev/null
}

tty_write() { printf '%b' "$1" >/dev/tty 2>/dev/null || true; }

alert() {
  tty_write '\a\033]0;opencode: SERVER DOWN\a'
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "opencode-remote" "$1" 2>/dev/null || true
  fi
}

flag=$(mktemp)
apid=""
wpid=""
stop=0

cleanup() {
  [ -n "$wpid" ] && kill "$wpid" 2>/dev/null
  rm -f "$flag"
}
trap cleanup EXIT
trap 'stop=1; [ -n "$apid" ] && kill "$apid" 2>/dev/null' INT TERM HUP

# Runs in the background while one attach is alive.
watch() {
  local down=0 misses=0 rings=0
  while sleep "$poll"; do
    if healthy; then
      misses=0
      if [ "$down" = 1 ]; then
        echo 1 >"$flag"
        kill -TERM "$apid" 2>/dev/null
        return
      fi
    else
      misses=$((misses + 1))
      if [ "$misses" -ge 2 ]; then
        if [ "$down" = 0 ]; then
          down=1
          alert "opencode-server is not answering ($health_url)"
        else
          # keep nagging about once a minute while it is down
          rings=$((rings + 1))
          [ $((rings * poll)) -ge 60 ] && { rings=0; alert "opencode-server is still down"; }
        fi
      fi
    fi
  done
}

while :; do
  : >"$flag"
  # <&0: a background job would otherwise get /dev/null as stdin and the TUI could not read the keyboard.
  "$@" <&0 &
  apid=$!
  watch &
  wpid=$!

  wait "$apid"
  status=$?
  kill "$wpid" 2>/dev/null
  wait "$wpid" 2>/dev/null
  wpid=""
  apid=""
  tty_write '\033]0;\a'

  [ "$stop" = 1 ] && exit "$status"

  # The watcher marks a deliberate restart by writing into the flag file.
  if [ -s "$flag" ]; then
    echo "opencode-remote: server is back, reattaching" >&2
    continue
  fi

  if healthy; then
    exit "$status"
  fi

  echo "opencode-remote: lost the server ($health_url); waiting for it, will reattach" >&2
  alert "opencode-server is down; opencode-remote is waiting"
  until healthy; do sleep "$poll"; done
  echo "opencode-remote: server is back, reattaching" >&2
done
