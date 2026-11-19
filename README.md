# Framework Privacy Indicators for Omarchy

An Omarchy bar plugin for the physical microphone **and** camera privacy switches
on Framework laptops. It is a fork of
[chalkers/omarchy-framework-microphone](https://github.com/chalkers/omarchy-framework-microphone)
combined into one plugin with two independently toggleable indicators.

Each icon reports both the hardware privacy slider and active PipeWire capture:

- **Blue microphone / camera:** the physical switch is on; the device is ready and idle.
- **Green:** an application is actively capturing from that device.
- **Red, crossed out:** the physical switch is off; the red slider is visible.
- **Amber warning:** the hardware state is unavailable or stale.

Hover for the hardware state and the capturing applications. Left-click either
icon for a popup with an on/off toggle for each indicator; right-click an icon
to toggle just that one directly. Turning an indicator off collapses its bar
slot. You can also control both from the command line.

## Requirements

- Omarchy 4
- A Framework laptop supported by `framework_tool --privacy`
- PipeWire

The Framework EC device is root-only. A small, hardened system service calls
`framework_tool` and writes a read-only state cache under `/run`. The shell
plugin and CLI read that cache without root access.

## Install

Add the fork and install the hardware cache service:

```bash
omarchy plugin add https://github.com/thatkes/omarchy-framework-privacy.git
~/.config/omarchy/plugins/thatkes.framework-privacy/setup.sh
```

Enable both indicators (one plugin instance per device):

```bash
omarchy plugin enable thatkes.framework-privacy --section centerEnd
omarchy bar put thatkes.framework-privacy --after thatkes.framework-privacy --section centerEnd
```

Then give the two instances their modes in `~/.config/omarchy/shell.json`:

```json
"centerEnd": [
  { "id": "thatkes.framework-privacy", "mode": "microphone" },
  { "id": "thatkes.framework-privacy", "mode": "camera" }
]
```

The shell hot-reloads `shell.json` on save. The setup script installs the
official Arch `framework-system` package, enables the cache service, and links
the CLI into `~/.local/bin`. Review `setup.sh` and `system/` before running it.

## Toggling indicators

From the bar: left-click an icon and use the switches in the popup, or
right-click an icon to toggle that device directly.

From the CLI:

```bash
framework-privacy status
framework-privacy status camera --json
framework-privacy toggle microphone      # aliases: mic
framework-privacy off camera             # aliases: cam, webcam
framework-privacy on mic
```

The on/off state lives in `~/.config/framework-privacy/state.json` and defaults
to both indicators on. If you turn off both icons, use the CLI to bring them
back.

## Remove

Uninstall the root service and CLI link first:

```bash
~/.config/omarchy/plugins/thatkes.framework-privacy/uninstall.sh
omarchy plugin remove thatkes.framework-privacy
```

## Validate

```bash
omarchy plugin validate ~/.config/omarchy/plugins/thatkes.framework-privacy
python3 ~/.config/omarchy/plugins/thatkes.framework-privacy/status.py --self-test
systemctl status framework-privacy-cache.service --no-pager
python -m json.tool /run/framework-privacy-waybar/state.json
framework-privacy status
```

## How it works

1. `framework-privacy-cache.service` runs `/usr/bin/framework_tool --privacy` once per second.
2. The service writes both slider states and a timestamp to `/run/framework-privacy-waybar/state.json`.
3. `status.py` reads the requested device's hardware state, checks PipeWire for a running
   `Stream/Input/Audio` or `Stream/Input/Video` capture, and reads the indicator on/off state.
4. `BarWidget.qml` runs `status.py <mode>` every two seconds and draws the icon, color, and tooltip.
5. The popup and `framework-privacy` CLI both write `~/.config/framework-privacy/state.json`.

## License

MIT. Based on the original work by chalkers.
