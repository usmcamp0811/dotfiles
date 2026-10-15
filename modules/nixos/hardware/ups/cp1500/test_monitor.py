import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import monitor


ACTIONS = {
    "power-loss": {"unit": "loss.service"},
    "power-restored": {"unit": "restore.service"},
    "low-battery": {"unit": "low.service"},
    "battery-half": {"unit": "half.service", "threshold": 50},
    "battery-critical": {"unit": "critical.service", "threshold": 10},
}


def initial():
    return {"version": 1, "on_battery": False, "fired": []}


class Transitions(unittest.TestCase):
    def plan(self, state, status, charge="100"):
        return monitor.plan(state, {"ups.status": status, "battery.charge": charge}, ACTIONS)

    def test_initial_online_has_no_restore_hook(self):
        state, events, _ = self.plan(initial(), "OL CHRG")
        self.assertEqual(events, [])
        self.assertFalse(state["on_battery"])

    def test_initial_outage_at_threshold(self):
        _, events, _ = self.plan(initial(), "OB DISCHRG", "50")
        self.assertEqual(events, ["power-loss", "battery-half"])

    def test_thresholds_are_not_hardcoded(self):
        actions = {"battery-custom": {"unit": "custom.service", "threshold": 72}}
        _, events, _ = monitor.plan(initial(), {"ups.status": "OB", "battery.charge": "71"}, actions)
        self.assertEqual(events, ["power-loss", "battery-custom"])

    def test_charge_jump_runs_high_threshold_first(self):
        state = {"version": 1, "on_battery": True, "fired": ["power-loss"]}
        _, events, _ = self.plan(state, "OB LB", "8")
        self.assertEqual(events, ["battery-half", "battery-critical", "low-battery"])

    def test_repeated_outage_does_not_repeat(self):
        state = {"version": 1, "on_battery": True, "fired": list(ACTIONS)}
        _, events, _ = self.plan(state, "OB LB", "5")
        self.assertEqual(events, [])

    def test_charge_increase_does_not_rearm(self):
        state = {"version": 1, "on_battery": True, "fired": ["power-loss", "battery-half"]}
        state, events, _ = self.plan(state, "OB", "60")
        self.assertEqual(events, [])
        _, events, _ = self.plan(state, "OB", "49.5")
        self.assertEqual(events, [])

    def test_online_rearms_next_outage(self):
        state = {"version": 1, "on_battery": True, "fired": list(ACTIONS)}
        state, events, _ = self.plan(state, "OL", "30")
        self.assertEqual(events, ["power-restored"])
        self.assertEqual(state["fired"], [])
        _, events, _ = self.plan(state, "OB", "30")
        self.assertEqual(events, ["power-loss", "battery-half"])

    def test_invalid_charge_does_not_hide_power_events(self):
        for charge in ("N/A", "nan", "inf", "-1", "101"):
            with self.subTest(charge=charge):
                _, events, value = self.plan(initial(), "OB LB", charge)
                self.assertIsNone(value)
                self.assertEqual(events, ["power-loss", "low-battery"])

    def test_unknown_status_fails_without_mutating_state(self):
        for status in ("", "UNKNOWN", "OL OB"):
            state = initial()
            with self.subTest(status=status), self.assertRaises(ValueError):
                self.plan(state, status)
            self.assertEqual(state, initial())


class Polling(unittest.TestCase):
    def config(self, directory):
        return {"upsc": "/mock/upsc", "systemctl": "/mock/systemctl",
                "ups": "cyberpower@127.0.0.1", "stateDir": directory, "actions": ACTIONS}

    def test_hooks_are_persisted_and_not_replayed_on_next_poll(self):
        with tempfile.TemporaryDirectory() as directory:
            calls = []

            def run(command, **kwargs):
                if command[0] == "/mock/upsc":
                    return subprocess.CompletedProcess(command, 0, "ups.status: OB\nbattery.charge: 8\n")
                calls.append(command[-1])
                state = json.loads((Path(directory) / "state.json").read_text())
                self.assertTrue(state["on_battery"])
                return subprocess.CompletedProcess(command, 0)

            with patch.object(monitor.subprocess, "run", side_effect=run):
                self.assertEqual(monitor.poll(self.config(directory)), 0)
                self.assertEqual(monitor.poll(self.config(directory)), 0)
            self.assertEqual(calls, ["loss.service", "half.service", "critical.service"])
            context = (Path(directory) / "battery-critical.env").read_text()
            self.assertIn('UPS_THRESHOLD="10"', context)
            self.assertIn('UPS_STATUS="OB"', context)
            self.assertEqual((Path(directory) / "state.json").stat().st_mode & 0o777, 0o600)

    def test_failed_hook_does_not_loop_and_later_hooks_still_run(self):
        with tempfile.TemporaryDirectory() as directory:
            calls = []

            def run(command, **kwargs):
                if command[0] == "/mock/upsc":
                    return subprocess.CompletedProcess(command, 0, "ups.status: OB\nbattery.charge: 8\n")
                calls.append(command[-1])
                return subprocess.CompletedProcess(command, 1)

            with patch.object(monitor.subprocess, "run", side_effect=run):
                self.assertEqual(monitor.poll(self.config(directory)), 1)
                self.assertEqual(monitor.poll(self.config(directory)), 0)
            self.assertEqual(calls, ["loss.service", "half.service", "critical.service"])

    def test_communication_failure_keeps_state(self):
        with tempfile.TemporaryDirectory() as directory:
            state_path = Path(directory) / "state.json"
            original = json.dumps({"version": 1, "on_battery": True, "fired": ["power-loss"]})
            state_path.write_text(original)
            with patch.object(monitor.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "upsc")):
                with self.assertRaises(subprocess.CalledProcessError):
                    monitor.poll(self.config(directory))
            self.assertEqual(state_path.read_text(), original)

    def test_corrupt_state_is_not_reset(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            path.write_text("corrupt")
            with self.assertRaises(ValueError):
                monitor.read_state(path)
            self.assertEqual(path.read_text(), "corrupt")


if __name__ == "__main__":
    unittest.main()
