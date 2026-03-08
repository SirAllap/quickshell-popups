# quickshell-popups

A collection of beautiful, theme-aware desktop popups for [Omarchy](https://omarchy.org/) /
[Hyprland](https://hyprland.org/), built with [Quickshell](https://quickshell.outfoxxed.me/).

Each popup is a standalone Quickshell project that can be toggled via a Waybar button or keybinding.
All popups share a unified theme bridge that reads your active Omarchy theme automatically.

---

## Popups

| Module | Toggle script | Description |
|--------|--------------|-------------|
| **CPU** | `toggle-cpu-popup` | Per-core usage, frequency, temperature, fan RPM/PWM, top processes |
| **GPU** | `toggle-gpu-popup` | GPU/VRAM usage, temperature, clock speeds, top GPU processes |
| **Memory** | `toggle-memory-popup` | RAM breakdown (used/cached/buffers/available), swap, DIMM info, clear cache |
| **Storage** | `toggle-storage-popup` | Per-disk usage and health (temperature, S.M.A.R.T. status) |
| **Network** | `toggle-network-popup` | WiFi/Ethernet panel, Bluetooth device management |
| **Weather** | `toggle-weather-popup` | Current conditions, hourly and 7-day forecast |
| **Media** | `toggle-media-popup` | MPRIS media controls, audio output selection |
| **Claude** | `toggle-claude-popup` | Claude API token/cost usage tracker |
| **Integrity** | `toggle-integrity-popup` | System health checks (disk, packages, services, etc.) |

---

## Requirements

- [Quickshell](https://quickshell.outfoxxed.me/) v0.2.1+
- Python 3.10+
- `jq`, `iproute2` (`ip`), `bluetoothctl`
- `dmidecode` (for DIMM info — needs sudo or sticky bit)
- `psutil` Python package (`pip install psutil` or `yay -S python-psutil`)
- [Omarchy](https://omarchy.org/) (for the theme bridge — or adapt `Theme.qml` to your setup)
- A [Nerd Font](https://www.nerdfonts.com/) (FontAwesome 4 range, e.g. JetBrainsMono Nerd Font)

---

## Installation

```bash
# 1. Clone into your Quickshell config directory
git clone https://github.com/SirAllap/quickshell-popups ~/.config/quickshell

# 2. Install toggle scripts to PATH
bash ~/.config/quickshell/bin/install.sh

# 3. (Optional) Integrate with Waybar — see Waybar section below
```

### What the install script does

`bin/install.sh` symlinks every `toggle-*-popup` script from `bin/` into `~/.local/bin/`,
making them available as commands everywhere.

---

## Waybar integration

Add these to your `~/.config/waybar/config.jsonc`. Adjust `exec` / `on-click` paths if you placed
the repo somewhere other than `~/.config/quickshell`.

```jsonc
// modules-left / center / right — add the module names you want:
"modules-left":   ["custom/cpu", "custom/gpu", "custom/memory", "custom/storage"],
"modules-center": ["custom/claude-usage", "custom/clock-weather", "custom/weather-popup",
                   "custom/network"],
"modules-right":  ["mpris", "custom/network-popup", "custom/system-integrity"],

// ── Module definitions ────────────────────────────────────────────────────────

"custom/cpu": {
  "format": "{}",
  "return-type": "json",
  "interval": 5,
  "exec": "~/.config/waybar/scripts/waybar-cpu.py",
  "on-click": "toggle-cpu-popup",
  "on-click-middle": "~/.config/waybar/scripts/waybar-cpu.py --toggle-fan-profile",
  "on-click-right": "omarchy-launch-or-focus-tui btop"
},
"custom/gpu": {
  "format": "{}",
  "return-type": "json",
  "interval": 5,
  "exec": "~/.config/waybar/scripts/waybar-gpu.py",
  "on-click": "toggle-gpu-popup",
  "on-click-right": "corectrl"
},
"custom/memory": {
  "format": "{}",
  "return-type": "json",
  "interval": 5,
  "exec": "~/.config/waybar/scripts/waybar-memory.py",
  "on-click": "toggle-memory-popup",
  "on-click-middle": "~/.config/waybar/scripts/waybar-memory.py --clear-cache"
},
"custom/storage": {
  "format": "{}",
  "return-type": "json",
  "interval": 5,
  "exec": "~/.config/waybar/scripts/waybar-storage.py",
  "on-click": "toggle-storage-popup",
  "on-click-right": "gnome-disks"
},
"custom/network-popup": {
  "return-type": "json",
  "exec": "~/.config/quickshell/network/waybar-network-popup.sh",
  "interval": 5,
  "format": "{}",
  "on-click": "toggle-network-popup"
},
"custom/system-integrity": {
  "format": "{}",
  "return-type": "json",
  "interval": 30,
  "exec": "~/.config/waybar/scripts/waybar-system-integrity.py",
  "on-click": "toggle-integrity-popup"
},
"custom/claude-usage": {
  "format": "{}",
  "return-type": "json",
  "interval": 5,
  "exec": "~/.config/waybar/scripts/waybar-claude-usage.py",
  "on-click": "toggle-claude-popup",
  "tooltip": true,
  "markup": "pango"
}
```

---

## Theme system

`Theme.qml` is the shared theme bridge. It reads
`~/.config/omarchy/current/theme/colors.toml` and exposes semantic color properties
(`base`, `surface0`, `text`, `blue`, `green`, `red`, etc.) that every popup uses.

The theme is re-read every 30 seconds, so theme switches take effect live.

**Using it in a popup:**

```qml
import "../"           // path to the root where Theme.qml lives

Item {
    Theme { id: theme }

    readonly property color base:   theme.base
    readonly property color blue:   theme.blue
    // …
}
```

**Adapting to a non-Omarchy setup:** Edit `Theme.qml` to point at your own color config,
or replace the `Process { command: ["cat", ...] }` block with any source that produces
the same `key = "#rrggbb"` format.

---

## Structure

```
~/.config/quickshell/
├── Theme.qml                    # Shared dynamic theme bridge
├── .gitignore
├── bin/
│   ├── install.sh               # Symlinks toggle scripts to ~/.local/bin/
│   ├── toggle-cpu-popup
│   ├── toggle-gpu-popup
│   ├── toggle-memory-popup
│   ├── toggle-storage-popup
│   ├── toggle-network-popup
│   ├── toggle-weather-popup
│   ├── toggle-media-popup
│   ├── toggle-claude-popup
│   └── toggle-integrity-popup
├── cpu/
│   ├── shell.qml                # Quickshell entry point
│   ├── CpuPopup.qml             # UI
│   └── cpu_data.py              # Data backend
├── gpu/
├── memory/
├── storage/
├── network/
│   ├── shell.qml
│   ├── NetworkPopup.qml
│   ├── ethernet_panel_logic.sh
│   ├── wifi_panel_logic.sh
│   ├── bluetooth_panel_logic.sh
│   ├── waybar-network-popup.sh  # Waybar button status script
│   └── sounds/                  # Connection audio feedback
├── weather/
├── media/
├── claude/
└── integrity/
```

---

## How popups work

Each module is a self-contained Quickshell project:

1. **`shell.qml`** — declares a `ShellRoot` with a `FloatingWindow`. A `HyprlandFocusGrab`
   closes the popup when focus leaves it.
2. **`XxxPopup.qml`** — the visual component. Uses `Process` + `StdioCollector` to run the
   Python/bash backend and parse JSON output.
3. **`xxx_data.py` / `xxx_logic.sh`** — lightweight data backend. Outputs a single JSON object
   to stdout.

**Toggling:** Each `toggle-*-popup` script checks `pgrep` — if the popup is running it kills it,
otherwise it launches it with `quickshell -p <dir>`.

---

## Notes

- **VRAM accounting**: GPU process VRAM via `/proc/PID/fdinfo` can show higher totals than the
  driver reports, because the Wayland compositor holds shared-buffer references for all clients.
  The popup filters compositor/system processes and uses the driver total (`mem_info_vram_used`)
  as the authoritative VRAM number.
- **Network interface detection**: Uses `ip route get 1.1.1.1` to find the interface actually
  routing to the internet, so it works correctly for ethernet, WiFi, VPNs, and multi-interface
  setups alike.
- **Icons**: All icons use FontAwesome 4 codepoints (≤ `\uf2e0`) for maximum Nerd Font
  compatibility. FA5 codepoints are intentionally avoided.

---

## License

MIT — do what you want, attribution appreciated.
