---
type: NixOS Module
title: CyberPower USB UPS monitoring and script hooks
description: fmf.hardware.ups.cp1500 supports CyberPower USB HID UPSes with matching vendor and product IDs, including the PR1500LCDRT2U, USB 0764:0601.
resource: ./default.nix
tags: [hardware, ups, cp1500]
---

# CyberPower USB UPS monitoring and script hooks

`fmf.hardware.ups.cp1500` supports CyberPower USB HID UPSes with matching vendor
and product IDs, including the **PR1500LCDRT2U, USB `0764:0601`**. The `cp1500`
option name is historical; it does not restrict the driver to that model.

The module uses NixOS's native Network UPS Tools (`usbhid-ups` + `upsd`) and a
small read-only status poller. There is one driver for the device, not competing
USB readers. **No automatic shutdown/reboot or UPS power-cut policy is enabled.**
You choose any machine actions explicitly in script hooks.

## Quick start

```nix
{
  fmf.hardware.ups.cp1500.enable = true;
}
```

That enables telemetry and journal messages only. No script actions, fixed
percentage thresholds, new Vault secrets, or externally accessible NUT port are
required. `upsd` listens on `127.0.0.1:3493`; status queries need no password.
NUT write/instant-command users are not configured.

### Run scripts for selected events

```nix
{pkgs, ...}: {
  fmf.hardware.ups.cp1500 = {
    enable = true;
    # Defaults match the USB UPS connected to sledge/reckless:
    vid = "0764";
    pid = "0601";
    pollInterval = 5;
    extraPackages = [pkgs.curl];

    onPowerLoss = ''
      echo "Mains failed on $UPS_NAME; charge=$UPS_BATTERY_CHARGE%"
      # Put your load-shedding/notification script here.
    '';
    onPowerRestored = ''
      echo "Mains restored on $UPS_NAME"
      # Put your recovery script here.
    '';
    onLowBattery = ''
      echo "UPS reports its native low-battery alarm"
    '';

    batteryActions = {
      shed-load = {
        percent = 50;
        script = ''
          echo "Battery reached $UPS_THRESHOLD%; reduce nonessential load"
        '';
      };
      critical = {
        percent = 10;
        script = ''
          echo "Battery reached $UPS_THRESHOLD%; perform the chosen critical action"
          # Example only: uncomment after reviewing your shutdown/recovery plan.
          # systemctl poweroff
        '';
      };
    };
  };
}
```

50 and 10 are **examples, not hardcoded triggers**. Add/remove named actions and
choose any integer threshold from 1 through 100. The UPS's native `LB` flag is
separate from these percentage checks and depends on its firmware/driver.
`onLowBattery` can therefore occur before or after a percentage hook. Do not
configure conflicting shutdown scripts in both places.

## Options

All options are under `fmf.hardware.ups.cp1500`.

| Option | Default | Meaning |
|---|---|---|
| `enable` | `false` | Enable driver, local telemetry server and event polling |
| `name` | `"cyberpower"` | NUT device name; changes the systemd unit/state prefixes |
| `vid` / `pid` | `"0764"` / `"0601"` | Four-digit hexadecimal USB IDs |
| `serial` | `null` | Optional NUT serial matching expression for device selection |
| `pollInterval` | `5` | Seconds after a poll finishes before another poll |
| `hookTimeout` | `"2min"` | Maximum runtime of each action service |
| `extraPackages` | `[]` | Extra packages on hook PATH, in addition to coreutils, systemd and NUT |
| `onPowerLoss` | `""` | Once when an on-battery (`OB`) condition is observed |
| `onPowerRestored` | `""` | On-line (`OL`) after an observed outage |
| `onLowBattery` | `""` | Native `LB` alarm, once per outage while on battery |
| `batteryActions.<name>.percent` | required | Charge at or below which to run, while on battery |
| `batteryActions.<name>.script` | required | Action script; empty disables it |

Names must start with an alphanumeric character and otherwise contain only
letters, digits, underscores or hyphens. For two matching USB devices on one
machine, select the intended one with `serial`; this module manages one UPS per
host. The USB bus/device numbers are not stable identifiers and are not used.

## Execution, state and failure semantics

- Scripts are separate **root** oneshot units. They can stop services or shut
  down the host: treat them as privileged system configuration. Empty hooks do
  nothing. No hook script is executed in NixOS's activation shell.
- Polling begins 30 seconds after boot. NUT queries have a ten-second timeout;
  polls do not overlap. Actions run sequentially: power loss, eligible percentage
  actions from highest threshold to lowest, then native low battery. A failed
  action is logged and later eligible actions are still attempted.
- Each hook has `hookTimeout`; a slow hook delays the next poll. Keep hooks
  short and idempotent. Prefer starting a separate service for long-running work.
- On first startup while already on battery, power loss and every eligible
  threshold fire. A jump from 80% to 8% triggers both 50% and 10% examples.
- Percentage/native-low actions are once **per outage**, not every poll. They
  re-arm only on a successfully observed `OL` status, not when battery charge
  briefly rises. Repeated `OB`/`OL` power flaps count as separate outages.
- Communication failure, stale NUT data or ambiguous status fails the check and
  retains its prior state; losing the USB connection is **not** treated as a
  power failure or restoration. Missing/invalid charge skips only percentage
  actions; status-based hooks can still run.
- State is atomically recorded before launching an action. Failed hooks do not
  automatically replay every poll. Inspect/restart the failed hook deliberately
  if retrying it is safe. This is best-effort event processing, not a guarantee
  of exactly-once execution across abrupt power loss. Corrupt state fails closed
  rather than replaying destructive actions.

Hook environment:

| Variable | Example |
|---|---|
| `UPS_NAME` | `cyberpower` |
| `UPS_EVENT` | `power-loss`, `power-restored`, `low-battery`, `battery-critical` |
| `UPS_STATUS` | `OB DISCHRG` |
| `UPS_BATTERY_CHARGE` | `48.5` (empty when unavailable) |
| `UPS_THRESHOLD` | `50` for percentage actions, otherwise empty |

State/context files are root-only in `/var/lib/ups-cyberpower-events`, with a
different prefix if `name` changes. On an impermanent host, persist that directory
to avoid re-firing outage hooks after a reboot. For example, alongside your
existing impermanence configuration:

```nix
environment.persistence."/persist/system".directories = [
  "/var/lib/ups-cyberpower-events"
];
```

Don't embed tokens/passwords in hook text: it enters the readable Nix store.
For notification credentials, use your existing Vault Agent pattern or systemd
credentials on the action unit. Reading local UPS telemetry needs no secret.

## Status and safe testing

After **you** apply the configuration:

```bash
upsc cyberpower@127.0.0.1 ups.status
upsc cyberpower@127.0.0.1 battery.charge
systemctl status upsd.service upsdrv.service ups-cyberpower-events.timer --no-pager
systemctl list-timers ups-cyberpower-events.timer --no-pager
sudo journalctl -u ups-cyberpower-events.service -n 100 --no-pager
# Names depend on which hooks are configured:
sudo journalctl -u ups-cyberpower-power-loss.service \
  -u ups-cyberpower-battery-critical.service -n 100 --no-pager
```

`upsmon.service` is intentionally disabled: it is not responsible for these
scripts. Successful event-poller oneshots normally become `inactive (dead)`.
Failures are recorded in unit status/journal; external alerts require a hook.

Start with `echo`-only hooks. When safe, test a short mains interruption by
unplugging the UPS's **mains input**, not the host's UPS output or USB cable.
Coordinate an outage first; never drain a production UPS just to test thresholds.
The included Python tests simulate thresholds, charge jumps, failures and state
recovery without contacting a UPS or executing system actions.

From the fmf checkout, run the stdlib-only tests with:

```bash
nix-shell -p python3 --run 'python3 -B modules/nixos/hardware/ups/cp1500/test_monitor.py -v'
```

Before maintenance, stop the timer and in-flight poller; stop any running hook
units too if needed:

```bash
sudo systemctl stop ups-cyberpower-events.timer ups-cyberpower-events.service
```

## Migration from the old module

The old module did not set `power.ups.enable`, used hand-written `/etc/nut` file
aliases and a placeholder `TODO` monitor password. On the inspected systems its
NUT services were inactive. This implementation explicitly enables native NUT,
removes those aliases/credentials, and leaves reboot/shutdown **opt-in**.
Remove old `environment.etc.upsmonConf`/`upsdConf`/`upsdUsers` overrides when using
the new module; they conflict with native NixOS configuration. The obsolete
reckless override is removed in the companion Campground change.

Publish the fmf changes and update the consumer's fmf pin before normal
deployment, or use a local input override for build-only checks. No live service
restart, mains interruption or deployment is implied by this documentation.
