---
type: NixOS Module
title: OpenCode headless server (fmf.services.opencode-server)
description: Runs `opencode serve` as a systemd service behind HTTP basic auth, with the password from Vault, and a watchdog that restarts it when it hangs.
resource: ./default.nix
tags: [services, opencode, agents]
status: draft
---

# OpenCode headless server (`fmf.services.opencode-server`)

Runs `opencode serve` for one user, protected by HTTP basic auth. The password is read from Vault by a
vault-agent sidecar and handed to the process as `OPENCODE_SERVER_PASSWORD`; the launcher refuses to start
with a missing, short, or awkward password, because an empty one means "no authentication". Clients attach
with `fmf.apps.opencode-remote`.

```nix
fmf.services.opencode-server = {
  enable = true;
  openFirewall = true;
  # watchdog.enable = true;   # the default
};
```

## Watchdog

`Restart=on-failure` restarts a server that exits. It cannot see one that is still running but no longer
answering (a hung event loop, a wedged runtime), which looks fine to systemd and dead to every client. The
watchdog covers that case with systemd's own watchdog (`Type=notify`, `WatchdogSec`):

1. A small supervisor (`supervise.sh`) runs the server and tells systemd it is **ready** only once an
   authenticated `GET /global/health` answers 2xx, so a unit is not `active` before it serves anything.
2. While serving, it probes every `interval` seconds. A healthy answer is a proof of life sent to systemd.
   No answer means no proof of life.
3. After `failures` probes' worth of silence systemd restarts the unit (which also kills the frozen
   process), and `Restart=on-failure` brings it back.

The probe uses the server's own credentials, passed to `curl` on its standard input, never on a command line.
A probe is a status code only; nothing from the response is read or logged.

| Option | Default | Meaning |
|---|---|---|
| `watchdog.enable` | `true` | Turn the whole thing off to get the plain `exec` behaviour back. |
| `watchdog.path` | `/global/health` | Path probed. Any 2xx counts. Change it if an older `opencode` has no such route. |
| `watchdog.interval` | `30` | Seconds between probes. |
| `watchdog.timeout` | `15` | Seconds a probe may take. Generous on purpose. |
| `watchdog.failures` | `4` | Probes that may fail in a row. With the defaults a hang is acted on after about three minutes (`(interval + timeout) * failures`). |
| `watchdog.startupGrace` | `120` | Seconds the server may take to start answering; after that the start fails. |

**It restarts the server, and with it every running session.** The numbers are deliberately slow so that a
machine that is merely busy (a long build in the same VM) does not look like a dead server. Lower
`failures` only if hangs are more common than slow stretches.

A stop does not wait for a hung server to honour SIGTERM: `TimeoutStopSec` is 20 seconds instead of the
default 90.

Checked by `checks/opencode-server-watchdog`, a NixOS VM test that builds its unit from the same helper
(`watchdog.nix`) and runs a stand-in that answers like `opencode serve`: a healthy server is left alone for
several watchdog periods, a frozen one (`SIGSTOP`) is restarted by the watchdog, a killed one is restarted,
a stop is prompt and leaves nothing behind, and a server that never answers fails its start with a clear
message.
