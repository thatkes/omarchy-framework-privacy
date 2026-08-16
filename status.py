#!/usr/bin/env python3
"""Report Framework microphone privacy and active PipeWire capture state."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

STATE_FILE = Path("/run/framework-privacy-waybar/state.json")
MAX_STATE_AGE_SECONDS = 5.0

ICONS = {
    "blocked": "󰍭",
    "ready": "󰍬",
    "active": "󰍬",
    "error": "",
}


def run(command: list[str], timeout: float = 2.0) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def parse_cached_microphone(payload: object, now: float | None = None) -> bool:
    if not isinstance(payload, dict):
        raise ValueError("privacy cache is not a JSON object")
    if payload.get("error"):
        raise RuntimeError(str(payload["error"]))

    connected = payload.get("microphone")
    if not isinstance(connected, bool):
        raise ValueError("privacy cache has invalid microphone state")

    updated = payload.get("updated")
    if not isinstance(updated, (int, float)):
        raise ValueError("privacy cache has no update timestamp")

    age = (time.time() if now is None else now) - float(updated)
    if age < -1.0 or age > MAX_STATE_AGE_SECONDS:
        raise RuntimeError(f"privacy cache is stale ({age:.1f}s old)")
    return connected


def get_hardware_state() -> bool:
    try:
        payload = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise RuntimeError("privacy cache service has not produced state") from error
    except json.JSONDecodeError as error:
        raise RuntimeError("privacy cache contains invalid JSON") from error
    return parse_cached_microphone(payload)


def application_name(props: dict[str, Any]) -> str:
    for key in (
        "application.name",
        "application.process.binary",
        "application.process.name",
        "node.name",
        "media.name",
    ):
        value = props.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return "unknown application"


def get_active_captures() -> set[str]:
    result = run(["pw-dump"])
    if result.returncode != 0:
        raise RuntimeError((result.stderr or "pw-dump failed").strip())

    try:
        objects = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("pw-dump returned invalid JSON") from error

    applications: set[str] = set()
    for item in objects if isinstance(objects, list) else []:
        if not isinstance(item, dict):
            continue
        info = item.get("info")
        if not isinstance(info, dict):
            continue
        props = info.get("props")
        if not isinstance(props, dict):
            continue
        state = info.get("state", item.get("state"))
        if str(state).lower() != "running":
            continue
        if str(props.get("media.class", "")) == "Stream/Input/Audio":
            applications.add(application_name(props))
    return applications


def render(connected: bool, applications: set[str]) -> dict[str, str]:
    if not connected:
        return {
            "icon": ICONS["blocked"],
            "state": "mic-blocked",
            "tooltip": "Framework microphone privacy\nHardware: DISCONNECTED — red slider\nActivity: idle",
        }

    if applications:
        names = ", ".join(sorted(applications, key=str.casefold))
        return {
            "icon": ICONS["active"],
            "state": "mic-active",
            "tooltip": f"Framework microphone privacy\nHardware: connected\nActivity: {names}",
        }

    return {
        "icon": ICONS["ready"],
        "state": "mic-ready",
        "tooltip": "Framework microphone privacy\nHardware: connected\nActivity: idle",
    }


def output_error(error: Exception) -> dict[str, str]:
    return {
        "icon": ICONS["error"],
        "state": "error",
        "tooltip": f"Framework microphone privacy state unavailable\n{error}",
    }


def self_test() -> None:
    assert parse_cached_microphone(
        {"microphone": True, "camera": False, "updated": 100.0}, now=100.5
    )
    try:
        parse_cached_microphone({"microphone": True, "updated": 90.0}, now=100.0)
    except RuntimeError as error:
        assert "stale" in str(error)
    else:
        raise AssertionError("stale cache was accepted")

    assert render(False, set())["state"] == "mic-blocked"
    assert render(True, set())["state"] == "mic-ready"
    active = render(True, {"Firefox"})
    assert active["state"] == "mic-active" and "Firefox" in active["tooltip"]
    print("framework-microphone status self-test: ok")


def main() -> None:
    import sys

    if "--self-test" in sys.argv[1:]:
        self_test()
        return

    try:
        payload = render(get_hardware_state(), get_active_captures())
    except Exception as error:
        payload = output_error(error)
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
