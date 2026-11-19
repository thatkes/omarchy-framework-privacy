#!/usr/bin/env python3
"""Report Framework privacy slider state for the microphone and camera.

Both indicators share the root-run cache service that writes the two hardware
slider states to /run/framework-privacy-waybar/state.json. This script adds
active PipeWire capture detection and the per-indicator on/off setting used by
the bar widget and the `framework-privacy` CLI.
"""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

CACHE_FILE = Path("/run/framework-privacy-waybar/state.json")
VISIBILITY_FILE = Path.home() / ".config/framework-privacy/state.json"
MAX_STATE_AGE_SECONDS = 5.0
ERROR_ICON = ""

DEVICES: dict[str, dict[str, Any]] = {
    "microphone": {
        "label": "Microphone",
        "icons": {"blocked": "󰍭", "ready": "󰍬", "active": "󰍬"},
        "capture_classes": ("Stream/Input/Audio",),
    },
    "camera": {
        "label": "Camera",
        "icons": {"blocked": "󰗟", "ready": "󰄀", "active": "󰄀"},
        "capture_classes": ("Stream/Input/Video",),
        "source_classes": ("Video/Source",),
    },
}

ALIASES = {
    "mic": "microphone",
    "microphone": "microphone",
    "cam": "camera",
    "camera": "camera",
    "webcam": "camera",
}


def normalize_device(value: str) -> str:
    key = str(value or "").strip().lower()
    if key not in ALIASES:
        raise ValueError(f"unknown device: {value!r}")
    return ALIASES[key]


def run(command: list[str], timeout: float = 2.0) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def parse_cached_state(payload: object, device: str, now: float | None = None) -> bool:
    if not isinstance(payload, dict):
        raise ValueError("privacy cache is not a JSON object")
    if payload.get("error"):
        raise RuntimeError(str(payload["error"]))

    connected = payload.get(device)
    if not isinstance(connected, bool):
        raise ValueError(f"privacy cache has invalid {device} state")

    updated = payload.get("updated")
    if not isinstance(updated, (int, float)):
        raise ValueError("privacy cache has no update timestamp")

    age = (time.time() if now is None else now) - float(updated)
    if age < -1.0 or age > MAX_STATE_AGE_SECONDS:
        raise RuntimeError(f"privacy cache is stale ({age:.1f}s old)")
    return connected


def get_hardware_state(device: str) -> bool:
    try:
        payload = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise RuntimeError("privacy cache service has not produced state") from error
    except json.JSONDecodeError as error:
        raise RuntimeError("privacy cache contains invalid JSON") from error
    return parse_cached_state(payload, device)


def read_visibility() -> dict[str, bool]:
    state = {name: True for name in DEVICES}
    try:
        payload = json.loads(VISIBILITY_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return state
    if not isinstance(payload, dict):
        return state

    for key, value in payload.items():
        try:
            name = normalize_device(key)
        except ValueError:
            continue
        state[name] = value is True
    return state


def write_visibility(device: str, enabled: bool) -> dict[str, bool]:
    name = normalize_device(device)
    state = read_visibility()
    state[name] = bool(enabled)

    VISIBILITY_FILE.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    temporary = VISIBILITY_FILE.with_name(VISIBILITY_FILE.name + ".tmp")
    temporary.write_text(
        json.dumps(state, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    temporary.chmod(0o644)
    temporary.replace(VISIBILITY_FILE)
    return state


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


def get_active_captures(device: str) -> set[str]:
    spec = DEVICES[device]
    capture_classes = set(spec["capture_classes"])
    source_classes = set(spec.get("source_classes", ()))

    result = run(["pw-dump"])
    if result.returncode != 0:
        raise RuntimeError((result.stderr or "pw-dump failed").strip())

    try:
        objects = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("pw-dump returned invalid JSON") from error

    applications: set[str] = set()
    source_active = False
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

        media_class = str(props.get("media.class", ""))
        if media_class in capture_classes:
            applications.add(application_name(props))
        elif media_class in source_classes:
            source_active = True

    # A browser or portal may keep only the source node running while it holds
    # the camera open, with no named client stream to report.
    if source_active and not applications:
        applications.add("camera stream")
    return applications


def render(
    device: str,
    connected: bool,
    applications: set[str],
    enabled: bool,
    visibility: dict[str, bool],
) -> dict[str, Any]:
    spec = DEVICES[device]
    label = spec["label"]

    if not connected:
        icon = spec["icons"]["blocked"]
        state = f"{device}-blocked"
        hardware_text = "DISCONNECTED — red slider"
        hardware = "disconnected"
        activity = "idle"
    elif applications:
        icon = spec["icons"]["active"]
        state = f"{device}-active"
        hardware_text = "connected"
        hardware = "connected"
        activity = ", ".join(sorted(applications, key=str.casefold))
    else:
        icon = spec["icons"]["ready"]
        state = f"{device}-ready"
        hardware_text = "connected"
        hardware = "connected"
        activity = "idle"

    return {
        "device": device,
        "label": label,
        "icon": icon,
        "state": state,
        "tooltip": (
            f"Framework {label.lower()} privacy\n"
            f"Hardware: {hardware_text}\n"
            f"Activity: {activity}\n"
            f"Indicator: {'on' if enabled else 'off'}"
        ),
        "enabled": enabled,
        "hardware": hardware,
        "activity": activity,
        "visibility": visibility,
    }


def output_error(error: Exception, device: str) -> dict[str, Any]:
    label = DEVICES[device]["label"]
    visibility = read_visibility()
    return {
        "device": device,
        "label": label,
        "icon": ERROR_ICON,
        "state": "error",
        "tooltip": f"Framework {label.lower()} privacy state unavailable\n{error}",
        "enabled": visibility.get(device, True),
        "hardware": "unknown",
        "activity": "unknown",
        "visibility": visibility,
    }


def get_status(device: str) -> dict[str, Any]:
    try:
        visibility = read_visibility()
        return render(
            device,
            get_hardware_state(device),
            get_active_captures(device),
            visibility.get(device, True),
            visibility,
        )
    except Exception as error:
        return output_error(error, device)


def self_test() -> None:
    assert normalize_device("mic") == "microphone"
    assert normalize_device("webcam") == "camera"

    assert parse_cached_state(
        {"microphone": True, "camera": False, "updated": 100.0}, "camera", now=100.5
    ) is False
    try:
        parse_cached_state({"microphone": True, "updated": 90.0}, "microphone", now=100.0)
    except RuntimeError as error:
        assert "stale" in str(error)
    else:
        raise AssertionError("stale cache was accepted")

    visibility = {"microphone": True, "camera": True}
    assert render("microphone", False, set(), True, visibility)["state"] == "microphone-blocked"
    assert render("camera", True, set(), True, visibility)["state"] == "camera-ready"

    active = render("camera", True, {"Firefox"}, True, visibility)
    assert active["state"] == "camera-active" and "Firefox" in active["tooltip"]

    global VISIBILITY_FILE
    original = VISIBILITY_FILE
    try:
        with tempfile.TemporaryDirectory() as directory:
            VISIBILITY_FILE = Path(directory) / "state.json"
            assert read_visibility() == visibility
            write_visibility("camera", False)
            assert read_visibility()["camera"] is False
            assert read_visibility()["microphone"] is True
            write_visibility("camera", True)
            assert read_visibility()["camera"] is True
    finally:
        VISIBILITY_FILE = original

    print("framework-privacy status self-test: ok")


def main() -> None:
    import sys

    args = sys.argv[1:]
    if "--self-test" in args:
        self_test()
        return
    if "--visibility" in args:
        print(json.dumps(read_visibility(), separators=(",", ":")))
        return
    if "--all" in args or not args:
        payload: Any = {name: get_status(name) for name in DEVICES}
    else:
        token = args[1] if args[0].startswith("--") and len(args) > 1 else args[0]
        device = normalize_device(token)
        payload = get_status(device)

    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
