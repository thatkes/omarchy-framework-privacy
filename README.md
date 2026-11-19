# Framework Privacy Indicators for Omarchy

An Omarchy bar plugin for the physical microphone **and** camera privacy switches
on Framework laptops. It is a fork of
[chalkers/omarchy-framework-microphone](https://github.com/chalkers/omarchy-framework-microphone)
with both indicators in one widget and one setup script.

The widget shows a microphone icon and a camera icon side by side. Each reports
the hardware privacy slider and active PipeWire capture:

- **Blue:** the physical switch is on; the device is ready and idle.
- **Green:** an application is actively capturing from that device.
- **Red, crossed out:** the physical switch is off; the red slider is visible.
- **Amber warning:** the hardware state is unavailable or stale.

Hover an icon for details. Left-click for a popup with an on/off switch for each
indicator; right-click an icon to toggle just that one. Turning both off
collapses the widget. The CLI controls the same settings.

## Requirements

- Omarchy 4
- A Framework laptop supported by `framework_tool --privacy`
- PipeWire

The Framework EC device is root-only, so `setup.sh` installs a small, hardened
system service that caches the slider state under `/run`. The widget and CLI
read that cache without root access.

## Install

```bash
omarchy plugin add https://github.com/thatkes/omarchy-framework-privacy.git
~/.config/omarchy/plugins/thatkes.framework-privacy/setup.sh
```

That is the whole setup. The single script installs the `framework-system`
package, installs and enables the cache service, links the CLI into
`~/.local/bin`, enables the plugin, and places one widget instance in the bar.
It is idempotent — re-running it changes nothing. Review `setup.sh` and `system/`
before running it.

## Toggling indicators

- Left-click either icon, then use the popup switches.
- Right-click an icon to toggle that device directly.
- CLI:
  ```bash
  framework-privacy status [--json]
  framework-privacy toggle microphone      # aliases: mic
  framework-privacy off camera             # aliases: cam, webcam
  framework-privacy on mic
  ```

The on/off state lives in `~/.config/framework-privacy/state.json` and defaults
to both indicators on. If you turn both off, use the CLI to bring them back.

## Manage

```bash
setup.sh status      # show service, CLI link, bar entry and live state
setup.sh uninstall   # remove the service, CLI link, bar entry and plugin enablement
```

Re-running `setup.sh` with no arguments re-installs everything.

## Validate

```bash
omarchy plugin validate ~/.config/omarchy/plugins/thatkes.framework-privacy
python3 ~/.config/omarchy/plugins/thatkes.framework-privacy/status.py --self-test
setup.sh status
```

## How it works

1. `framework-privacy-cache.service` runs `/usr/bin/framework_tool --privacy` once per second.
2. The service writes both slider states and a timestamp to `/run/framework-privacy-waybar/state.json`.
3. `status.py` reads both devices' hardware state, checks PipeWire for running
   `Stream/Input/Audio` and `Stream/Input/Video` captures, and reads the on/off state.
4. `BarWidget.qml` runs `status.py` every two seconds and draws both icons, colors and tooltips.
5. The popup and `framework-privacy` CLI both write `~/.config/framework-privacy/state.json`.

## License

MIT. Based on the original work by chalkers.
