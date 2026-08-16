# Framework Microphone Privacy for Omarchy

An Omarchy bar plugin for the physical microphone privacy switch on Framework laptops.

The icon reports both hardware privacy and active PipeWire capture:

- **Blue microphone:** The physical switch is on. The microphone is ready and idle.
- **Green microphone:** An application is actively capturing audio.
- **Red crossed microphone:** The physical switch is off. The red slider is visible.
- **Amber warning:** The hardware state is unavailable or stale.

Move the pointer over the icon to see the hardware state and active applications.
Click the icon to refresh the state.

## Requirements

- Omarchy 4
- A Framework laptop supported by `framework_tool --privacy`
- PipeWire

The Framework EC device is root-only. A small, hardened system service calls the official
`framework_tool` command and writes a read-only state cache under `/run`. The shell plugin reads
that cache without root access.

## Install

Add the plugin:

```bash
omarchy plugin add https://github.com/chalkers/omarchy-framework-microphone.git
```

Install and start the hardware cache service:

```bash
~/.config/omarchy/plugins/chalkers.framework-microphone/setup.sh
```

Enable the bar widget:

```bash
omarchy plugin enable chalkers.framework-microphone
```

The widget starts in the center section. Move it when necessary:

```bash
omarchy bar move chalkers.framework-microphone --section right
```

The setup script installs the official Arch `framework-system` package. It also uses `sudo` to
install and enable `framework-privacy-cache.service`. Review `setup.sh` and the files under
`system/` before you run the script.

## Remove

Remove the root cache service first:

```bash
~/.config/omarchy/plugins/chalkers.framework-microphone/uninstall.sh
```

Then remove the plugin:

```bash
omarchy plugin remove chalkers.framework-microphone
```

## Validate

```bash
omarchy plugin validate .
./status.py --self-test
./system/framework-privacy-cache --self-test
systemctl status framework-privacy-cache.service --no-pager
python -m json.tool /run/framework-privacy-waybar/state.json
```

## How it works

1. `framework-privacy-cache.service` runs `/usr/bin/framework_tool --privacy` once per second.
2. The service writes the microphone state and timestamp to `/run/framework-privacy-waybar/state.json`.
3. `status.py` reads the cache and checks PipeWire for active audio capture streams.
4. `BarWidget.qml` refreshes the icon and tooltip every two seconds.

The service uses systemd hardening options. It can only write to its runtime cache directory.

## License

MIT
