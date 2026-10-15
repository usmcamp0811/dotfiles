"""Read-only NUT event polling. All machine actions live in separate hook units."""

import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def atomic_write(path, text):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as f:
        temporary = Path(f.name)
        try:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    try:
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        temporary.unlink(missing_ok=True)


def read_state(path):
    if not path.exists():
        return {"version": 1, "on_battery": False, "fired": []}
    state = json.loads(path.read_text())
    if (state.get("version") != 1 or type(state.get("on_battery")) is not bool
            or not isinstance(state.get("fired"), list)
            or not all(isinstance(name, str) for name in state["fired"])):
        raise ValueError("Invalid UPS event state; refusing to repeat hooks")
    return state


def plan(state, sample, actions):
    """Pure state transition; return next state, ordered events and charge."""
    flags = set(sample.get("ups.status", "").split())
    if ("OB" in flags) == ("OL" in flags):
        raise ValueError("UPS status must unambiguously report OB or OL")
    charge = None
    try:
        value = float(sample["battery.charge"])
        if math.isfinite(value) and 0 <= value <= 100:
            charge = value
    except (KeyError, ValueError):
        pass
    if "OL" in flags:
        events = ["power-restored"] if state["on_battery"] else []
        return {"version": 1, "on_battery": False, "fired": []}, events, charge

    next_state = {"version": 1, "on_battery": True,
                  "fired": list(state["fired"]) if state["on_battery"] else []}
    events = ["power-loss"]
    thresholds = sorted(
        ((name, action["threshold"]) for name, action in actions.items()
         if "threshold" in action), key=lambda item: (-item[1], item[0]))
    if charge is not None:
        events += [name for name, threshold in thresholds if charge <= threshold]
    if "LB" in flags:
        events.append("low-battery")
    return next_state, [name for name in events if name not in next_state["fired"]], charge


def poll(config):
    response = subprocess.run([config["upsc"], config["ups"]],
                              capture_output=True, text=True, timeout=10, check=True)
    sample = dict(line.split(": ", 1) for line in response.stdout.splitlines()
                  if ": " in line)
    directory = Path(config["stateDir"])
    state_path = directory / "state.json"
    previous = read_state(state_path)
    state, events, charge = plan(previous, sample, config["actions"])
    if state != previous or not state_path.exists():
        atomic_write(state_path, json.dumps(state) + "\n")
    failed = False
    if charge is None:
        print("UPS battery.charge missing/invalid; percentage actions skipped", file=sys.stderr)
    for name in events:
        action = config["actions"].get(name)
        # Record before invoking a potentially destructive hook. Failures are
        # visible in the journal and are not automatically replayed every poll.
        if state["on_battery"]:
            state["fired"].append(name)
            atomic_write(state_path, json.dumps(state) + "\n")
        print(f"UPS {config['ups']}: {name}, status={sample['ups.status']}, charge={charge}", flush=True)
        if action is None:
            continue
        environment = {
            "UPS_NAME": config["ups"].split("@", 1)[0], "UPS_EVENT": name,
            "UPS_STATUS": sample["ups.status"],
            "UPS_BATTERY_CHARGE": "" if charge is None else str(charge),
            "UPS_THRESHOLD": str(action.get("threshold", "")),
        }
        atomic_write(directory / f"{name}.env", "".join(
            f"{key}={json.dumps(value)}\n" for key, value in environment.items()))
        result = subprocess.run([config["systemctl"], "start", action["unit"]], check=False)
        if result.returncode:
            print(f"UPS hook failed: {action['unit']} (not replaying automatically)", file=sys.stderr)
            failed = True
    return 1 if failed else 0


def main():
    try:
        return poll(json.loads(Path(sys.argv[1]).read_text()))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"UPS event check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
